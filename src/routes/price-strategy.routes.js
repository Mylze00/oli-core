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

module.exports = router;
