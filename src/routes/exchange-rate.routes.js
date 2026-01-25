const express = require('express');
const router = express.Router();
const exchangeRateController = require('../controllers/exchange-rate.controller');
const { requireAuth, requireRole } = require('../middlewares/auth.middleware');

/**
 * Routes publiques pour les taux de change
 */

// Récupérer le taux actuel
router.get('/current', exchangeRateController.getCurrentRate);

// Convertir un montant
router.get('/convert', exchangeRateController.convertAmount);

// Récupérer l'historique des taux
router.get('/history', exchangeRateController.getRateHistory);

// Récupérer les statistiques
router.get('/statistics', exchangeRateController.getStatistics);

/**
 * Routes admin
 */

// Forcer la mise à jour des taux
router.post('/refresh', requireAuth, requireRole('admin'), exchangeRateController.refreshRates);

module.exports = router;
