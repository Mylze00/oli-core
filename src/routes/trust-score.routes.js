const express = require('express');
const router = express.Router();
const trustScoreController = require('../controllers/trust-score.controller');
const { requireAuth, requireAdmin } = require('../middleware/auth');

/**
 * Routes pour la gestion des trust scores
 */

// Routes utilisateur
router.get('/my-score', requireAuth, trustScoreController.getMyTrustScore);

// Routes admin
router.get('/statistics', requireAuth, requireAdmin, trustScoreController.getStatistics);
router.get('/high-risk-users', requireAuth, requireAdmin, trustScoreController.getHighRiskUsers);
router.post('/:userId/flag', requireAuth, requireAdmin, trustScoreController.flagUser);

module.exports = router;
