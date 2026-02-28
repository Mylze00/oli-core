/**
 * price-strategy.routes.js
 * Routes pour la stratégie de prix et l'analyse concurrence via CSV
 */

const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { calculerStrategieProduit, loadCompetitorCSV, invalidateCache } = require('../services/pricing.strategy');

/**
 * POST /api/price-strategy/analyze
 * Analyse la stratégie de prix sans modifier le produit
 * Body: { nom?, prixAchat, poids, longueur?, largeur?, hauteur?, prixConcurrent?, product_id? }
 */
router.post('/analyze', async (req, res) => {
    try {
        let { nom, prixAchat, poids, longueur, largeur, hauteur, prixConcurrent, product_id } = req.body;

        // Si product_id fourni → charger les données depuis la DB
        if (product_id) {
            const [rows] = await db.query(
                'SELECT name, price, weight FROM products WHERE id = ? LIMIT 1',
                [product_id]
            );
            if (!rows || rows.length === 0) {
                return res.status(404).json({ error: 'Produit introuvable' });
            }
            nom = nom || rows[0].name;
            prixAchat = prixAchat || parseFloat(rows[0].price) / 1.35; // estimer le prix achat
            poids = poids || parseFloat(rows[0].weight) || 0.5;
        }

        if (!prixAchat || isNaN(parseFloat(prixAchat))) {
            return res.status(400).json({ error: 'prixAchat est requis et doit être un nombre' });
        }

        const result = calculerStrategieProduit({
            nom, prixAchat, poids, longueur, largeur, hauteur, prixConcurrent
        });

        res.json({ success: true, analysis: result });
    } catch (err) {
        console.error('❌ price-strategy/analyze:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/apply
 * Applique le prix conseillé sur un produit existant en DB
 * Body: { product_id, apply_price: true }
 * Requiert : être propriétaire du produit OU admin
 */
router.post('/apply', async (req, res) => {
    try {
        const { product_id, apply_price, prixAchat, poids, longueur, largeur, hauteur } = req.body;

        if (!product_id) {
            return res.status(400).json({ error: 'product_id requis' });
        }

        // Charger le produit
        const [rows] = await db.query(
            'SELECT id, name, price, weight FROM products WHERE id = ? LIMIT 1',
            [product_id]
        );
        if (!rows || rows.length === 0) {
            return res.status(404).json({ error: 'Produit introuvable' });
        }

        const product = rows[0];
        const nomProduit = product.name;
        const prixAchatCalc = parseFloat(prixAchat) || parseFloat(product.price) / 1.35;
        const poidsCalc = parseFloat(poids) || parseFloat(product.weight) || 0.5;

        const result = calculerStrategieProduit({
            nom: nomProduit,
            prixAchat: prixAchatCalc,
            poids: poidsCalc,
            longueur: longueur || 20,
            largeur: largeur || 20,
            hauteur: hauteur || 10,
        });

        // Appliquer le prix si demandé
        if (apply_price) {
            await db.query(
                'UPDATE products SET price = ? WHERE id = ?',
                [result.prixVenteNumber, product_id]
            );
        }

        res.json({
            success: true,
            product_id,
            applied: !!apply_price,
            analysis: result,
        });
    } catch (err) {
        console.error('❌ price-strategy/apply:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/apply-bulk
 * Applique la stratégie de prix sur TOUS les produits du vendeur connecté
 * Body: { apply_price?: boolean, poids_defaut?: number }
 */
router.post('/apply-bulk', async (req, res) => {
    try {
        const { apply_price = false, poids_defaut = 0.5 } = req.body;

        const [products] = await db.query(
            'SELECT id, name, price, weight FROM products WHERE status = "active" LIMIT 500'
        );

        const results = [];
        for (const product of products) {
            const prixAchat = parseFloat(product.price) / 1.35;
            const poids = parseFloat(product.weight) || poids_defaut;

            const analysis = calculerStrategieProduit({
                nom: product.name,
                prixAchat,
                poids,
                longueur: 20, largeur: 20, hauteur: 10,
            });

            if (apply_price) {
                await db.query(
                    'UPDATE products SET price = ? WHERE id = ?',
                    [analysis.prixVenteNumber, product.id]
                );
            }

            results.push({ product_id: product.id, nom: product.name, ...analysis });
        }

        res.json({
            success: true,
            total: results.length,
            applied: apply_price,
            results,
        });
    } catch (err) {
        console.error('❌ price-strategy/apply-bulk:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * POST /api/price-strategy/reload-csv
 * Recharge le cache CSV (utile en dev local)
 */
router.post('/reload-csv', (req, res) => {
    invalidateCache();
    const competitors = loadCompetitorCSV();
    res.json({ success: true, loaded: competitors.length });
});

module.exports = router;
