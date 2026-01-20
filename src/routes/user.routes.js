/**
 * Routes User - Profil et activité utilisateur
 */
const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');

/**
 * GET /user/visited-products
 * Récupère l'historique des produits visités par l'utilisateur
 */
router.get('/visited-products', userController.getVisitedProducts);

/**
 * POST /user/track-view/:productId
 * Enregistre une vue de produit
 */
router.post('/track-view/:productId', userController.trackProductView);

/**
 * PUT /user/update-name
 * Met à jour le nom de l'utilisateur
 */
router.put('/update-name', userController.updateName);

module.exports = router;
