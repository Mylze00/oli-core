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
    SEUIL_ABERRANT: 10000,
    BATCH_SIZE: 50,
    DELAY_BETWEEN_BATCH_MS: 2000,
    INTERVAL_HOURS: 6,
    DIMENSIONS_DEFAUT: { longueur: 30, largeur: 30, hauteur: 20 },
    POIDS_DEFAUT: 0.5,
    ADMIN_SELLER_ID: null, // Auto-détecté au 1er run
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

    // Chercher par nom 'OLI' ou 'oli' ou le shop vérifié
    const result = await db.query(
        "SELECT id FROM users WHERE LOWER(username) = 'oli' OR LOWER(first_name) = 'oli' OR role = 'admin' ORDER BY id LIMIT 1"
    );
    if (result.rows.length > 0) {
        CONFIG.ADMIN_SELLER_ID = result.rows[0].id;
        console.log(`🤖 Admin OLI détecté: seller_id = ${CONFIG.ADMIN_SELLER_ID}`);
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

            if (prixActuel > CONFIG.SEUIL_ABERRANT) {
                prixAchat = prixActuel / CONFIG.TAUX_CHANGE;
                correction = 'FC->USD';
                stats.aberrants++;
            } else if (prixActuel < 2 && prixActuel > 0) {
                const mediane = medianes[product.category];
                if (mediane && mediane > 2) {
                    prixAchat = mediane / 1.35;
                } else {
                    prixAchat = 15;
                }
                correction = 'prix-trop-bas';
                stats.trop_bas++;
            } else if (prixActuel > 0) {
                prixAchat = prixActuel / 1.35;
                correction = 'recalcul-marge';
            } else {
                stats.ignores++;
                continue;
            }

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
            const changement = Math.abs(nouveauPrix - prixActuel) / Math.max(prixActuel, 1);

            if (correction === 'FC->USD' || correction === 'prix-trop-bas' || changement > 0.1) {
                await db.query(
                    'UPDATE products SET price = $1 WHERE id = $2',
                    [nouveauPrix, product.id]
                );
                stats.corriges++;
                console.log(`  [${product.id}] ${product.name.substring(0, 40)} | $${prixActuel.toFixed(0)} -> $${nouveauPrix.toFixed(2)} (${correction})`);
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
async function runPriceAnalysis() {
    if (_isRunning) {
        console.log('Price Worker: deja en cours, skip');
        return;
    }

    _isRunning = true;
    const startTime = Date.now();
    const stats = {
        debut: new Date().toISOString(),
        traites: 0, corriges: 0, aberrants: 0, trop_bas: 0,
        inchanges: 0, ignores: 0, erreurs: 0, total: 0,
    };

    console.log('');
    console.log('=== PRICE WORKER - Analyse des prix admin OLI ===');

    try {
        // 0. Trouver le seller_id admin
        const adminId = await findAdminSellerId();
        if (!adminId) {
            _isRunning = false;
            _lastRunStats = { ...stats, erreur: 'Admin OLI non trouve' };
            return;
        }

        // 1. Compter les produits admin seulement
        const countResult = await db.query(
            "SELECT COUNT(*) AS total FROM products WHERE seller_id = $1 AND status = 'active'",
            [adminId]
        );
        stats.total = parseInt(countResult.rows[0].total);
        stats.admin_seller_id = adminId;
        console.log(`Total produits admin OLI (seller_id=${adminId}): ${stats.total}`);

        // 2. Medianes par categorie (tous produits pour reference)
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

            console.log(`\nBatch ${Math.floor(offset / CONFIG.BATCH_SIZE) + 1} (${offset + 1}-${offset + result.rows.length}/${stats.total})`);
            await processBatch(result.rows, medianes, stats);

            offset += CONFIG.BATCH_SIZE;
            await sleep(CONFIG.DELAY_BETWEEN_BATCH_MS);
        }

        stats.duree_secondes = ((Date.now() - startTime) / 1000).toFixed(1);
        stats.fin = new Date().toISOString();

        console.log('');
        console.log('=== PRICE WORKER TERMINE ===');
        console.log(`  Traites: ${stats.traites}/${stats.total}`);
        console.log(`  Corriges: ${stats.corriges}`);
        console.log(`  Aberrants FC->USD: ${stats.aberrants}`);
        console.log(`  Prix trop bas: ${stats.trop_bas}`);
        console.log(`  Inchanges: ${stats.inchanges}`);
        console.log(`  Erreurs: ${stats.erreurs}`);
        console.log(`  Duree: ${stats.duree_secondes}s`);

    } catch (err) {
        console.error('Price Worker CRASH:', err);
        stats.crash = err.message;
    }

    _lastRunStats = stats;
    _isRunning = false;
}

function startWorker() {
    console.log(`Price Worker: demarrage dans 30s, puis toutes les ${CONFIG.INTERVAL_HOURS}h`);
    setTimeout(() => { runPriceAnalysis(); }, 30000);
    setInterval(() => { runPriceAnalysis(); }, CONFIG.INTERVAL_HOURS * 60 * 60 * 1000);
}

module.exports = { startWorker, runPriceAnalysis, getStats, CONFIG };
