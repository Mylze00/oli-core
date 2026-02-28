/**
 * price-worker.js
 * Worker en arrière-plan qui analyse et corrige les prix des produits
 * - Détecte les prix aberrants (FC stocké comme USD)
 * - Recalcule le prix réel avec stratégie transport
 * - Met à jour la DB progressivement (1 produit à la fois)
 * - Se relance toutes les 6 heures
 */

const db = require('../config/db');
const { calculerStrategieProduit } = require('./pricing.strategy');

// ── Configuration ──────────────────────────────────────────────────────────
const CONFIG = {
    TAUX_CHANGE: 2800,           // 1 USD = 2800 FC
    SEUIL_ABERRANT: 10000,       // Prix > $10,000 = probablement en FC
    BATCH_SIZE: 50,              // Produits traités par batch
    DELAY_BETWEEN_BATCH_MS: 2000,// Pause entre chaque batch (2s)
    INTERVAL_HOURS: 6,           // Relancer toutes les 6 heures
    DIMENSIONS_DEFAUT: { longueur: 30, largeur: 30, hauteur: 20 },
    POIDS_DEFAUT: 0.5,
};

// ── Stats du dernier run ───────────────────────────────────────────────────
let _lastRunStats = null;
let _isRunning = false;

/**
 * Retourne les stats du dernier run
 */
function getStats() {
    return { isRunning: _isRunning, lastRun: _lastRunStats };
}

/**
 * Pause utilitaire
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Analyse et corrige un lot de produits
 */
async function processBatch(products, medianes, stats) {
    for (const product of products) {
        try {
            const prixActuel = parseFloat(product.price) || 0;
            const poids = parseFloat(product.weight) || CONFIG.POIDS_DEFAUT;
            let prixAchat = 0;
            let correction = 'aucune';

            // ── Détection du type de prix aberrant ─────────────────────────
            if (prixActuel > CONFIG.SEUIL_ABERRANT) {
                // CAS 1: Prix probablement en FC → convertir en USD
                prixAchat = prixActuel / CONFIG.TAUX_CHANGE;
                correction = 'FC->USD';
                stats.aberrants++;
            } else if (prixActuel < 2 && prixActuel > 0) {
                // CAS 2: Prix trop bas ($1 = prix MOQ fournisseur)
                // Utiliser la médiane de la catégorie comme prix d'achat réaliste
                const mediane = medianes[product.category];
                if (mediane && mediane > 2) {
                    prixAchat = mediane / 1.35;
                } else {
                    prixAchat = 15; // fallback raisonnable si pas de médiane
                }
                correction = 'prix-trop-bas';
                stats.trop_bas++;
            } else if (prixActuel > 0) {
                // CAS 3: Prix normal → estimer le prix d'achat (inverse de la marge 35%)
                prixAchat = prixActuel / 1.35;
                correction = 'recalcul-marge';
            } else {
                // Prix = 0 ou négatif → ignorer
                stats.ignores++;
                continue;
            }

            // ── Calcul stratégie ───────────────────────────────────────────
            const analysis = calculerStrategieProduit({
                nom: product.name,
                prixAchat,
                poids,
                longueur: CONFIG.DIMENSIONS_DEFAUT.longueur,
                largeur: CONFIG.DIMENSIONS_DEFAUT.largeur,
                hauteur: CONFIG.DIMENSIONS_DEFAUT.hauteur,
                prixConcurrent: medianes[product.category] || null,
            });

            const nouveauPrix = analysis.prixVenteNumber;

            // ── Mise à jour si le prix change significativement ────────────
            const changement = Math.abs(nouveauPrix - prixActuel) / Math.max(prixActuel, 1);
            if (correction === 'FC->USD' || changement > 0.1) {
                await db.query(
                    'UPDATE products SET price = $1 WHERE id = $2',
                    [nouveauPrix, product.id]
                );
                stats.corriges++;
                console.log(`  ✅ [${product.id}] ${product.name.substring(0, 40)} | $${prixActuel.toFixed(0)} → $${nouveauPrix.toFixed(2)} (${correction})`);
            } else {
                stats.inchanges++;
            }

            stats.traites++;
        } catch (err) {
            stats.erreurs++;
            console.warn(`  ⚠️ [${product.id}] Erreur:`, err.message);
        }
    }
}

/**
 * Lance l'analyse complète de tous les produits
 */
async function runPriceAnalysis() {
    if (_isRunning) {
        console.log('🔄 Price Worker: déjà en cours, skip');
        return;
    }

    _isRunning = true;
    const startTime = Date.now();
    const stats = {
        debut: new Date().toISOString(),
        traites: 0,
        corriges: 0,
        aberrants: 0,
        trop_bas: 0,
        inchanges: 0,
        ignores: 0,
        erreurs: 0,
        total: 0,
    };

    console.log('');
    console.log('═══════════════════════════════════════════════');
    console.log('🤖 PRICE WORKER - Analyse des prix en cours...');
    console.log('═══════════════════════════════════════════════');

    try {
        // 1. Compter le total
        const countResult = await db.query(
            "SELECT COUNT(*) AS total FROM products WHERE status = 'active'"
        );
        stats.total = parseInt(countResult.rows[0].total);
        console.log(`📊 Total produits actifs: ${stats.total}`);

        // 2. Pré-calculer toutes les médianes par catégorie (1 requête)
        const medResult = await db.query(
            "SELECT category, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE status = 'active' AND price > 0 AND price < $1 GROUP BY category",
            [CONFIG.SEUIL_ABERRANT]
        );
        const medianes = {};
        for (const row of medResult.rows) {
            medianes[row.category] = parseFloat(row.median_price);
        }
        console.log(`📈 Médianes calculées pour ${Object.keys(medianes).length} catégories`);

        // 3. Traiter par batch
        let offset = 0;
        while (offset < stats.total) {
            const result = await db.query(
                "SELECT id, name, price, weight, category FROM products WHERE status = 'active' ORDER BY id OFFSET $1 LIMIT $2",
                [offset, CONFIG.BATCH_SIZE]
            );

            if (result.rows.length === 0) break;

            console.log(`\n📦 Batch ${Math.floor(offset / CONFIG.BATCH_SIZE) + 1} (${offset + 1}-${offset + result.rows.length}/${stats.total})`);
            await processBatch(result.rows, medianes, stats);

            offset += CONFIG.BATCH_SIZE;
            await sleep(CONFIG.DELAY_BETWEEN_BATCH_MS);
        }

        stats.duree_secondes = ((Date.now() - startTime) / 1000).toFixed(1);
        stats.fin = new Date().toISOString();

        console.log('');
        console.log('═══════════════════════════════════════════════');
        console.log('🏁 PRICE WORKER - Terminé !');
        console.log(`   📊 Traités: ${stats.traites}/${stats.total}`);
        console.log(`   ✅ Corrigés: ${stats.corriges}`);
        console.log(`   🔴 Aberrants (FC→USD): ${stats.aberrants}`);
        console.log(`   ⏭️  Inchangés: ${stats.inchanges}`);
        console.log(`   ⚠️  Erreurs: ${stats.erreurs}`);
        console.log(`   ⏱️  Durée: ${stats.duree_secondes}s`);
        console.log('═══════════════════════════════════════════════');

    } catch (err) {
        console.error('❌ Price Worker CRASH:', err);
        stats.crash = err.message;
    }

    _lastRunStats = stats;
    _isRunning = false;
}

/**
 * Démarre le worker avec un délai initial + intervalle de répétition
 */
function startWorker() {
    console.log(`🤖 Price Worker: démarrage dans 30s, puis toutes les ${CONFIG.INTERVAL_HOURS}h`);

    // Premier run après 30 secondes (laisser le serveur démarrer)
    setTimeout(() => {
        runPriceAnalysis();
    }, 30000);

    // Puis toutes les X heures
    setInterval(() => {
        runPriceAnalysis();
    }, CONFIG.INTERVAL_HOURS * 60 * 60 * 1000);
}

module.exports = { startWorker, runPriceAnalysis, getStats, CONFIG };
