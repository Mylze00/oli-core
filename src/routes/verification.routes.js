const express = require('express');
const router = express.Router();
const verificationController = require('../controllers/verification.controller');
const { requireAuth, requireAdmin } = require('../middleware/auth');

/**
 * Routes pour la gestion des niveaux de vérification
 */

// Routes utilisateur
router.get('/my-level', requireAuth, verificationController.getMyVerificationLevel);

// Routes admin
router.get('/statistics', requireAuth, requireAdmin, verificationController.getStatistics);
router.get('/users-by-level/:level', requireAuth, requireAdmin, verificationController.getUsersByLevel);

module.exports = router;
