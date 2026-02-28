/**
 * price-strategy.routes.js
 * Routes pour la stratégie de prix et l'analyse concurrence via CSV + médiane DB
 */

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { calculerStrategieProduit, loadCompetitorCSV, invalidateCache } = require('../services/pricing.strategy');

/**
 * POST /api/price-strategy/analyze
 * Analyse la stratégie de prix sans modifier le produit
 */
router.post('/analyze', async (req, res) => {
    try {
        let { nom, prixAchat, poids, longueur, largeur, hauteur, prixConcurrent, product_id } = req.body;
        let category = null;

        if (product_id) {
            const result = await db.query(
                'SELECT name, price, weight, category FROM products WHERE id = $1 LIMIT 1',
                [product_id]
            );
            if (!result.rows || result.rows.length === 0) {
                return res.status(404).json({ error: 'Produit introuvable' });
            }
            nom = nom || result.rows[0].name;
            prixAchat = prixAchat || parseFloat(result.rows[0].price) / 1.35;
            poids = poids || parseFloat(result.rows[0].weight) || 0.5;
            category = result.rows[0].category;
        }

        if (!prixAchat || isNaN(parseFloat(prixAchat))) {
            return res.status(400).json({ error: 'prixAchat est requis et doit etre un nombre' });
        }

        // Fallback concurrent : mediane des prix de meme categorie
        let sourceConc = 'aucune';
        if (!prixConcurrent && category) {
            const medResult = await db.query(
                "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE category = $1 AND status = 'active' AND price > 0",
                [category]
            );
            if (medResult.rows[0] && medResult.rows[0].median_price) {
                prixConcurrent = parseFloat(medResult.rows[0].median_price);
                sourceConc = 'mediane categorie: ' + category;
            }
        }

        // Fallback global
        if (!prixConcurrent) {
            const globalResult = await db.query(
                "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE status = 'active' AND price > 0"
            );
            if (globalResult.rows[0] && globalResult.rows[0].median_price) {
                prixConcurrent = parseFloat(globalResult.rows[0].median_price);
                sourceConc = 'mediane globale';
            }
        }

        const analysis = calculerStrategieProduit({
            nom, prixAchat, poids, longueur, largeur, hauteur, prixConcurrent
        });

        res.json({ success: true, analysis, source_concurrent: sourceConc });
    } catch (err) {
        console.error('price-strategy/analyze error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/apply
 * Applique le prix conseille sur un produit existant en DB
 */
router.post('/apply', async (req, res) => {
    try {
        const { product_id, apply_price, prixAchat, poids, longueur, largeur, hauteur } = req.body;

        if (!product_id) {
            return res.status(400).json({ error: 'product_id requis' });
        }

        const result = await db.query(
            'SELECT id, name, price, weight, category FROM products WHERE id = $1 LIMIT 1',
            [product_id]
        );
        if (!result.rows || result.rows.length === 0) {
            return res.status(404).json({ error: 'Produit introuvable' });
        }

        const product = result.rows[0];
        const prixAchatCalc = parseFloat(prixAchat) || parseFloat(product.price) / 1.35;
        const poidsCalc = parseFloat(poids) || parseFloat(product.weight) || 0.5;

        // Mediane categorie comme prix concurrent
        let prixConcurrent = null;
        if (product.category) {
            const medResult = await db.query(
                "SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE category = $1 AND status = 'active' AND price > 0",
                [product.category]
            );
            if (medResult.rows[0] && medResult.rows[0].median_price) {
                prixConcurrent = parseFloat(medResult.rows[0].median_price);
            }
        }

        const analysis = calculerStrategieProduit({
            nom: product.name,
            prixAchat: prixAchatCalc,
            poids: poidsCalc,
            longueur: longueur || 20,
            largeur: largeur || 20,
            hauteur: hauteur || 10,
            prixConcurrent,
        });

        if (apply_price) {
            await db.query(
                'UPDATE products SET price = $1 WHERE id = $2',
                [analysis.prixVenteNumber, product_id]
            );
        }

        res.json({ success: true, product_id, applied: !!apply_price, analysis });
    } catch (err) {
        console.error('price-strategy/apply error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/apply-bulk
 * Applique la strategie sur tous les produits actifs
 * Body: { apply_price?: boolean, poids_defaut?: number, page?: number, limit?: number }
 */
router.post('/apply-bulk', async (req, res) => {
    try {
        const { apply_price = false, poids_defaut = 0.5, page = 1, limit = 500 } = req.body;
        const offset = (Math.max(1, parseInt(page)) - 1) * parseInt(limit);
        const lim = Math.min(parseInt(limit), 1000);

        // 1. Compter le total
        const countResult = await db.query("SELECT COUNT(*) AS total FROM products WHERE status = 'active'");
        const totalProducts = parseInt(countResult.rows[0].total);

        // 2. Pre-calculer TOUTES les medianes par categorie en 1 requete
        const medResult = await db.query(
            "SELECT category, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price FROM products WHERE status = 'active' AND price > 0 GROUP BY category"
        );
        const medianes = {};
        for (const row of medResult.rows) {
            medianes[row.category] = parseFloat(row.median_price);
        }

        // 3. Charger les produits de cette page
        const result = await db.query(
            "SELECT id, name, price, weight, category FROM products WHERE status = 'active' ORDER BY id OFFSET $1 LIMIT $2",
            [offset, lim]
        );
        const products = result.rows || [];

        const results = [];
        for (const product of products) {
            const prixAchat = parseFloat(product.price) / 1.35;
            const poids = parseFloat(product.weight) || poids_defaut;
            const prixConcurrent = medianes[product.category] || null;

            const analysis = calculerStrategieProduit({
                nom: product.name, prixAchat, poids,
                longueur: 20, largeur: 20, hauteur: 10,
                prixConcurrent,
            });

            if (apply_price) {
                await db.query(
                    'UPDATE products SET price = $1 WHERE id = $2',
                    [analysis.prixVenteNumber, product.id]
                );
            }

            results.push({ product_id: product.id, nom: product.name, categorie: product.category, ...analysis });
        }

        const totalPages = Math.ceil(totalProducts / lim);
        res.json({
            success: true,
            total_products: totalProducts,
            page: parseInt(page),
            total_pages: totalPages,
            count: results.length,
            applied: apply_price,
            results,
        });
    } catch (err) {
        console.error('price-strategy/apply-bulk error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/reload-csv
 */
router.post('/reload-csv', (req, res) => {
    invalidateCache();
    const competitors = loadCompetitorCSV();
    res.json({ success: true, loaded: competitors.length });
});

/**
 * POST /api/price-strategy/fix-aberrant
 * Detecte et corrige les prix aberrants (prix en FC stockes comme USD)
 * Body: { 
 *   taux_change: number (ex: 2800),  // 1 USD = 2800 FC
 *   seuil_max_usd: number (ex: 10000), // au-dessus = aberrant
 *   apply_fix: boolean,  // true = modifier en DB
 *   page: number, limit: number 
 * }
 */
router.post('/fix-aberrant', async (req, res) => {
    try {
        const {
            taux_change = 2800,
            seuil_max_usd = 10000,
            apply_fix = false,
            page = 1,
            limit = 500
        } = req.body;

        const offset = (Math.max(1, parseInt(page)) - 1) * parseInt(limit);
        const lim = Math.min(parseInt(limit), 1000);

        // Compter les produits aberrants
        const countResult = await db.query(
            "SELECT COUNT(*) AS total FROM products WHERE status = 'active' AND price > $1",
            [seuil_max_usd]
        );
        const totalAberrant = parseInt(countResult.rows[0].total);

        // Charger les produits aberrants de cette page
        const result = await db.query(
            "SELECT id, name, price, weight, category FROM products WHERE status = 'active' AND price > $1 ORDER BY price DESC OFFSET $2 LIMIT $3",
            [seuil_max_usd, offset, lim]
        );
        const products = result.rows || [];

        const results = [];
        for (const product of products) {
            const prixOriginal = parseFloat(product.price);
            // Le prix stocke est en FC → convertir en USD
            const prixAchatUSD = prixOriginal / taux_change;
            const poids = parseFloat(product.weight) || 0.5;

            const analysis = calculerStrategieProduit({
                nom: product.name,
                prixAchat: prixAchatUSD,
                poids,
                longueur: 30, largeur: 30, hauteur: 20,
            });

            if (apply_fix) {
                await db.query(
                    'UPDATE products SET price = $1 WHERE id = $2',
                    [analysis.prixVenteNumber, product.id]
                );
            }

            results.push({
                product_id: product.id,
                nom: product.name.substring(0, 60),
                prix_actuel: '$' + prixOriginal.toFixed(2),
                prix_achat_estime_usd: '$' + prixAchatUSD.toFixed(2),
                nouveau_prix: analysis.prixVenteConseille,
                transport: analysis.mode,
                frais_transport: analysis.fraisExpe,
            });
        }

        const totalPages = Math.ceil(totalAberrant / lim);
        res.json({
            success: true,
            total_aberrants: totalAberrant,
            page: parseInt(page),
            total_pages: totalPages,
            count: results.length,
            taux_change_utilise: taux_change,
            seuil_usd: seuil_max_usd,
            applied: apply_fix,
            results,
        });
    } catch (err) {
        console.error('price-strategy/fix-aberrant error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});
/**
 * POST /api/price-strategy/rollback
 * Restaure les prix des produits NON-ADMIN modifies par erreur par le worker
 * Body: { apply_rollback: boolean, restore_price?: number }
 */
router.post('/rollback', async (req, res) => {
    try {
        const { apply_rollback = false, restore_price = null } = req.body;

        // 1. Trouver le seller_id admin OLI
        const adminResult = await db.query(
            "SELECT id, name FROM users WHERE LOWER(name) = 'oli' ORDER BY id LIMIT 1"
        );
        if (!adminResult.rows.length) {
            return res.status(404).json({ error: 'Admin OLI non trouve' });
        }
        const adminId = adminResult.rows[0].id;

        // 2. Trouver TOUS les produits NON-admin modifies aujourd'hui
        const result = await db.query(
            "SELECT p.id, p.name AS product_name, p.price, p.seller_id, u.name AS seller_name FROM products p LEFT JOIN users u ON p.seller_id = u.id WHERE p.seller_id != $1 AND p.updated_at >= CURRENT_DATE ORDER BY p.seller_id, p.id",
            [adminId]
        );
        const affectes = result.rows || [];

        if (apply_rollback && affectes.length > 0) {
            const prix = restore_price || 1;
            for (const p of affectes) {
                await db.query('UPDATE products SET price = $1 WHERE id = $2', [prix, p.id]);
            }
        }

        // Grouper par vendeur pour le résumé
        const parVendeur = {};
        for (const p of affectes) {
            const seller = p.seller_name || 'Inconnu';
            if (!parVendeur[seller]) parVendeur[seller] = { count: 0, seller_id: p.seller_id };
            parVendeur[seller].count++;
        }

        res.json({
            success: true,
            admin_id: adminId,
            admin_name: adminResult.rows[0].name,
            total_affectes: affectes.length,
            applied: apply_rollback,
            restore_price: apply_rollback ? (restore_price || 1) : null,
            par_vendeur: parVendeur,
            produits: affectes.slice(0, 100).map(p => ({
                id: p.id,
                nom: (p.product_name || '').substring(0, 50),
                prix_actuel: '$' + parseFloat(p.price).toFixed(2),
                seller: p.seller_name,
            })),
        });
    } catch (err) {
        console.error('price-strategy/rollback error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/restore-csv
 * Restaure les prix depuis le CSV original import_boutique_shoppi.csv
 * Body: { apply: boolean, taux_change?: number }
 */
router.post('/restore-csv', async (req, res) => {
    try {
        const { apply = false, taux_change = 2800 } = req.body;
        const fs = require('fs');
        const path = require('path');

        // Lire le CSV original
        const csvPath = path.join(__dirname, '../../data/import_boutique_shoppi.csv');
        if (!fs.existsSync(csvPath)) {
            return res.status(404).json({ error: 'CSV non trouve', path: csvPath });
        }

        const csvContent = fs.readFileSync(csvPath, 'utf-8');
        const lines = csvContent.split('\n');
        const header = lines[0]; // ID;Nom;Description;Prix;Stock;Catégorie;...

        // Parser les prix du CSV (séparateur ;)
        const csvPrices = {};
        for (let i = 1; i < lines.length; i++) {
            const cols = lines[i].split(';');
            if (cols.length < 4) continue;
            const nom = (cols[1] || '').trim();
            const prixFC = parseFloat(cols[3]) || 0;
            if (nom && prixFC > 0) {
                csvPrices[nom.toLowerCase()] = prixFC;
            }
        }

        console.log(`CSV: ${Object.keys(csvPrices).length} produits avec prix`);

        // Trouver dans la DB les produits qui matchent
        const result = await db.query(
            "SELECT id, name, price FROM products WHERE status = 'active'"
        );
        const dbProducts = result.rows || [];

        let matched = 0, updated = 0, notFound = 0;
        const details = [];

        for (const p of dbProducts) {
            const key = (p.name || '').trim().toLowerCase();
            const prixFC = csvPrices[key];
            if (!prixFC) continue;
            matched++;

            const prixUSD = parseFloat((prixFC / taux_change).toFixed(2));
            const prixActuel = parseFloat(p.price) || 0;

            if (Math.abs(prixUSD - prixActuel) > 0.01) {
                if (apply) {
                    await db.query('UPDATE products SET price = $1 WHERE id = $2', [prixUSD, p.id]);
                }
                updated++;
                details.push({
                    id: p.id,
                    nom: p.name.substring(0, 45),
                    prix_fc: prixFC,
                    prix_usd_csv: prixUSD,
                    prix_actuel: prixActuel,
                });
            }
        }

        res.json({
            success: true,
            csv_total: Object.keys(csvPrices).length,
            db_total: dbProducts.length,
            matched,
            a_mettre_a_jour: updated,
            applied: apply,
            taux_change,
            exemples: details.slice(0, 50),
        });
    } catch (err) {
        console.error('price-strategy/restore-csv error:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

module.exports = router;
