const express = require('express');
const router = express.Router();
const trustScoreController = require('../controllers/trust-score.controller');
const { requireAuth, requireRole } = require('../middlewares/auth.middleware');

/**
 * Routes pour la gestion des trust scores
 */

// Routes utilisateur
router.get('/my-score', requireAuth, trustScoreController.getMyTrustScore);

// Routes admin
router.get('/statistics', requireAuth, requireRole('admin'), trustScoreController.getStatistics);
router.get('/high-risk-users', requireAuth, requireRole('admin'), trustScoreController.getHighRiskUsers);
router.post('/:userId/flag', requireAuth, requireRole('admin'), trustScoreController.flagUser);

module.exports = router;
