const express = require('express');
const router = express.Router();
const behaviorController = require('../controllers/behavior.controller');
const { requireAuth, requireRole } = require('../middlewares/auth.middleware');

/**
 * Routes pour le tracking comportemental
 */

// Routes utilisateur
router.post('/track', requireAuth, behaviorController.trackEvent);
router.get('/my-history', requireAuth, behaviorController.getMyHistory);
router.get('/my-analysis', requireAuth, behaviorController.getMyAnalysis);

// Routes admin
router.get('/statistics', requireAuth, requireRole('admin'), behaviorController.getStatistics);

module.exports = router;
