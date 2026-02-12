/**
 * Routes pour les méthodes de livraison
 * GET /api/delivery-methods — Liste toutes les méthodes actives
 * GET /api/delivery-methods/product/:productId — Méthodes dispo pour un produit
 * GET /api/delivery-methods/estimate — Calculer prix partenaire (distance)
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');

/**
 * Calcul distance Haversine (en km)
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Calcul frais livraison partenaire
 */
function calculatePartnerFee(distanceKm) {
    const BASE_FEE = 2.00;   // $2 base
    const PER_KM = 0.50;     // $0.50/km
    const MIN_FEE = 2.00;    // minimum $2
    const MAX_FEE = 25.00;   // plafond $25
    const fee = BASE_FEE + (distanceKm * PER_KM);
    return Math.min(Math.max(fee, MIN_FEE), MAX_FEE);
}

/**
 * GET /api/delivery-methods
 * Liste toutes les méthodes de livraison actives
 */
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM delivery_methods WHERE is_active = true ORDER BY sort_order'
        );
        res.json(result.rows);
    } catch (err) {
        console.error('Error GET /delivery-methods:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /api/delivery-methods/product/:productId
 * Méthodes de livraison disponibles pour un produit spécifique
 * Combine les méthodes du produit (shipping_options) avec les infos de delivery_methods
 */
router.get('/product/:productId', async (req, res) => {
    try {
        const { productId } = req.params;

        // Récupérer le produit avec ses shipping_options
        const productResult = await pool.query(
            'SELECT shipping_options FROM products WHERE id = $1',
            [productId]
        );

        if (productResult.rows.length === 0) {
            return res.status(404).json({ error: 'Produit non trouvé' });
        }

        const shippingOptions = productResult.rows[0].shipping_options || [];

        if (shippingOptions.length === 0) {
            return res.json([]);
        }

        // Récupérer les infos complètes des méthodes
        const methodIds = shippingOptions.map(o => o.methodId);
        const methodsResult = await pool.query(
            'SELECT * FROM delivery_methods WHERE id = ANY($1) AND is_active = true ORDER BY sort_order',
            [methodIds]
        );

        // Fusionner les infos méthode + prix du vendeur
        const methods = methodsResult.rows.map(method => {
            const option = shippingOptions.find(o => o.methodId === method.id);
            return {
                ...method,
                cost: option ? option.cost : null,
                time: option ? option.time : null,
            };
        });

        res.json(methods);
    } catch (err) {
        console.error('Error GET /delivery-methods/product/:productId:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /api/delivery-methods/estimate
 * Calculer le prix estimé pour un livreur partenaire
 * Query params: sellerLat, sellerLng, buyerLat, buyerLng
 */
router.get('/estimate', async (req, res) => {
    try {
        const { sellerLat, sellerLng, buyerLat, buyerLng } = req.query;

        if (!sellerLat || !sellerLng || !buyerLat || !buyerLng) {
            return res.status(400).json({
                error: 'Paramètres manquants: sellerLat, sellerLng, buyerLat, buyerLng'
            });
        }

        const distance = calculateDistance(
            parseFloat(sellerLat), parseFloat(sellerLng),
            parseFloat(buyerLat), parseFloat(buyerLng)
        );

        const fee = calculatePartnerFee(distance);

        res.json({
            distance_km: Math.round(distance * 10) / 10,
            delivery_fee: Math.round(fee * 100) / 100,
            base_fee: 2.00,
            per_km: 0.50,
            currency: 'USD'
        });
    } catch (err) {
        console.error('Error GET /delivery-methods/estimate:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
