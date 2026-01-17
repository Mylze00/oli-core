/**
 * Routes User - Profil et activité utilisateur
 */
const express = require('express');
const router = express.Router();
const userService = require('../services/user.service');

/**
 * GET /user/visited-products
 * Récupère l'historique des produits visités par l'utilisateur
 */
router.get('/visited-products', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;
        const products = await userService.getVisitedProducts(req.user.id, limit);
        res.json(products);
    } catch (error) {
        console.error('Erreur /user/visited-products:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /user/track-view/:productId
 * Enregistre une vue de produit
 */
router.post('/track-view/:productId', async (req, res) => {
    try {
        const productId = parseInt(req.params.productId);

        if (!productId || isNaN(productId)) {
            return res.status(400).json({ error: 'Product ID invalide' });
        }

        await userService.trackProductView(req.user.id, productId);
        res.json({ success: true, message: 'Vue enregistrée' });
    } catch (error) {
        console.error('Erreur /user/track-view:', error);
        // On retourne quand même success pour ne pas bloquer l'UX
        res.json({ success: true, message: 'Vue non enregistrée' });
    }
});

/**
 * PUT /user/update-name
 * Met à jour le nom de l'utilisateur
 */
router.put('/update-name', async (req, res) => {
    try {
        const { name } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Le nom est requis' });
        }

        const updatedUser = await userService.updateUserName(req.user.id, name);
        res.json({
            success: true,
            message: 'Nom mis à jour',
            user: updatedUser
        });
    } catch (error) {
        console.error('Erreur /user/update-name:', error);
        res.status(400).json({ error: error.message });
    }
});

module.exports = router;
