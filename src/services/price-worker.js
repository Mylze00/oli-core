/**
 * price-worker.js
 * Worker en arrière-plan qui analyse et corrige les prix des produits
 * ⚠️ NE TRAITE QUE les produits du vendeur admin OLI (auto-détecté)
 */

const db = require('../config/db');
const { calculerStrategieProduit } = require('./pricing.strategy');

// ── Configuration ──────────────────────────────────────────────────────────
const CONFIG = {
    TAUX_CHANGE: 2800,
    SEUIL_ABERRANT: 10000,      // Prix > $10 000 USD = aberrant absolu (FC non converti)
    SEUIL_MEDIANE_RATIO: 50,    // Prix > 50× médiane catégorie = suspect
    BATCH_SIZE: 100,
    DELAY_BETWEEN_BATCH_MS: 1000,
    DELAY_MANUAL_MS: 0,         // Pas de délai en mode manuel
    INTERVAL_HOURS: 6,
    DIMENSIONS_DEFAUT: { longueur: 30, largeur: 30, hauteur: 20 },
    POIDS_DEFAUT: 0.5,
    ADMIN_SELLER_ID: null,
};

let _lastRunStats = null;
let _isRunning = false;

function getStats() {
    return { isRunning: _isRunning, lastRun: _lastRunStats };
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Auto-détecte le seller_id du compte admin OLI
 */
async function findAdminSellerId() {
    if (CONFIG.ADMIN_SELLER_ID) return CONFIG.ADMIN_SELLER_ID;

    // Priorité 1 : is_admin = true
    let result = await db.query(
        "SELECT id, name FROM users WHERE is_admin = true ORDER BY id LIMIT 1"
    );
    // Fallback : chercher par nom 'OLI'
    if (!result.rows.length) {
        result = await db.query(
            "SELECT id, name FROM users WHERE LOWER(name) = 'oli' ORDER BY id LIMIT 1"
        );
    }
    if (result.rows.length > 0) {
        CONFIG.ADMIN_SELLER_ID = result.rows[0].id;
        console.log(`🤖 Admin OLI détecté: seller_id = ${CONFIG.ADMIN_SELLER_ID} (${result.rows[0].name})`);
        return CONFIG.ADMIN_SELLER_ID;
    }

    console.warn('⚠️ ADMIN OLI non trouvé ! Worker annulé.');
    return null;
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

            if (prixActuel <= 0) {
                stats.ignores++;
                continue;
            }

            const mediane = medianes[product.category] || null;

            if (prixActuel > CONFIG.SEUIL_ABERRANT) {
                // Cas 1 : prix > $10 000 → clairement stocké en FC
                prixAchat = prixActuel / CONFIG.TAUX_CHANGE;
                correction = 'FC->USD';
                stats.aberrants++;
            } else if (mediane && mediane > 1 && prixActuel > mediane * CONFIG.SEUIL_MEDIANE_RATIO) {
                // Cas 2 : prix > 50× la médiane de sa catégorie → suspect
                prixAchat = prixActuel / CONFIG.TAUX_CHANGE;
                correction = 'FC->USD-median';
                stats.aberrants++;
                console.log(`  [${product.id}] Aberrant par médiane: $${prixActuel} > 50×$${mediane.toFixed(2)} | ${product.name.substring(0, 40)}`);
            } else if (prixActuel < 2) {
                // Cas 3 : prix trop bas (< $2)
                prixAchat = mediane ? mediane / 1.35 : 15;
                correction = 'prix-trop-bas';
                stats.trop_bas++;
            } else {
                // Cas 4 : recalcul de marge standard
                prixAchat = prixActuel / 1.35;
                correction = 'recalcul-marge';
            }

            const analysis = calculerStrategieProduit({
                nom: product.name,
                prixAchat,
                poids,
                longueur: CONFIG.DIMENSIONS_DEFAUT.longueur,
                largeur: CONFIG.DIMENSIONS_DEFAUT.largeur,
                hauteur: CONFIG.DIMENSIONS_DEFAUT.hauteur,
                prixConcurrent: mediane,
            });

            const nouveauPrix = analysis.prixVenteNumber;
            const changement = Math.abs(nouveauPrix - prixActuel) / Math.max(prixActuel, 1);

            if (correction === 'FC->USD' || correction === 'FC->USD-median' || correction === 'prix-trop-bas' || changement > 0.1) {
                await db.query(
                    'UPDATE products SET price = $1 WHERE id = $2',
                    [nouveauPrix, product.id]
                );
                stats.corriges++;
                console.log(`  [${product.id}] ${product.name.substring(0, 40)} | $${prixActuel.toFixed(2)} -> $${nouveauPrix.toFixed(2)} (${correction})`);
            } else {
                stats.inchanges++;
            }

            stats.traites++;
        } catch (err) {
            stats.erreurs++;
            console.warn(`  [${product.id}] Erreur:`, err.message);
        }
    }
}

/**
 * Lance l'analyse - UNIQUEMENT pour les produits admin OLI
 */
async function runPriceAnalysis(opts = {}) {
    if (_isRunning) {
        console.log('Price Worker: deja en cours, skip');
        return _lastRunStats;
    }

    const manualMode = opts.manual === true;
    const delayMs = manualMode ? CONFIG.DELAY_MANUAL_MS : CONFIG.DELAY_BETWEEN_BATCH_MS;

    _isRunning = true;
    const startTime = Date.now();
    const stats = {
        debut: new Date().toISOString(),
        traites: 0, corriges: 0, aberrants: 0, trop_bas: 0,
        inchanges: 0, ignores: 0, erreurs: 0, total: 0,
        mode: manualMode ? 'manuel' : 'auto',
    };

    console.log('');
    console.log(`=== PRICE WORKER - Analyse OLI (${stats.mode}) ===`);

    try {
        // 0. Trouver le seller_id admin
        const adminId = await findAdminSellerId();
        if (!adminId) {
            _isRunning = false;
            _lastRunStats = { ...stats, erreur: 'Admin OLI non trouve' };
            return _lastRunStats;
        }
        stats.admin_seller_id = adminId;

        // 1. Compter les produits admin seulement
        const countResult = await db.query(
            "SELECT COUNT(*) AS total FROM products WHERE seller_id = $1 AND status = 'active'",
            [adminId]
        );
        stats.total = parseInt(countResult.rows[0].total);
        console.log(`Total produits admin OLI (seller_id=${adminId}): ${stats.total}`);

        // 2. Medianes par categorie (tous produits, seuil 10× SEUIL_ABERRANT pour inclure les bas prix)
        const medResult = await db.query(
            "SELECT category, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE status = 'active' AND price > 0 AND price < $1 GROUP BY category",
            [CONFIG.SEUIL_ABERRANT]
        );
        const medianes = {};
        for (const row of medResult.rows) {
            medianes[row.category] = parseFloat(row.median_price);
        }
        console.log(`Medianes calculees pour ${Object.keys(medianes).length} categories`);

        // 3. Traiter par batch - FILTRE seller_id = admin
        let offset = 0;
        while (offset < stats.total) {
            const result = await db.query(
                "SELECT id, name, price, weight, category FROM products WHERE seller_id = $1 AND status = 'active' ORDER BY id OFFSET $2 LIMIT $3",
                [adminId, offset, CONFIG.BATCH_SIZE]
            );

            if (result.rows.length === 0) break;

            console.log(`Batch ${Math.floor(offset / CONFIG.BATCH_SIZE) + 1} (${offset + 1}-${offset + result.rows.length}/${stats.total})`);
            await processBatch(result.rows, medianes, stats);

            offset += CONFIG.BATCH_SIZE;
            if (delayMs > 0) await sleep(delayMs);
        }

        stats.duree_secondes = ((Date.now() - startTime) / 1000).toFixed(1);
        stats.fin = new Date().toISOString();

        console.log('=== PRICE WORKER TERMINE ===');
        console.log(`  Traites: ${stats.traites}/${stats.total} | Corriges: ${stats.corriges} | Aberrants: ${stats.aberrants} | Trop bas: ${stats.trop_bas} | Erreurs: ${stats.erreurs} | Duree: ${stats.duree_secondes}s`);

    } catch (err) {
        console.error('Price Worker CRASH:', err);
        stats.crash = err.message;
        stats.duree_secondes = ((Date.now() - startTime) / 1000).toFixed(1);
    }

    _lastRunStats = stats;
    _isRunning = false;
    return stats;
}

function startWorker() {
    console.log(`Price Worker: demarrage dans 30s, puis toutes les ${CONFIG.INTERVAL_HOURS}h`);
    setTimeout(() => { runPriceAnalysis(); }, 30000);
    setInterval(() => { runPriceAnalysis(); }, CONFIG.INTERVAL_HOURS * 60 * 60 * 1000);
}

module.exports = { startWorker, runPriceAnalysis, getStats, CONFIG };
