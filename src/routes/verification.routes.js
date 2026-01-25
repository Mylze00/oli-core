const express = require('express');
const router = express.Router();
const verificationController = require('../controllers/verification.controller');
const { requireAuth, requireRole } = require('../middlewares/auth.middleware');

/**
 * Routes pour la gestion des niveaux de vérification
 */

// Routes utilisateur
router.get('/my-level', requireAuth, verificationController.getMyVerificationLevel);

// Routes admin
router.get('/statistics', requireAuth, requireRole('admin'), verificationController.getStatistics);
router.get('/users-by-level/:level', requireAuth, requireRole('admin'), verificationController.getUsersByLevel);

module.exports = router;
