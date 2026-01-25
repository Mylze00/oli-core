const express = require('express');
const router = express.Router();
const identityController = require('../controllers/identity.controller');
const { requireAuth, requireAdmin } = require('../middleware/auth');

/**
 * Routes pour la gestion des documents d'identité
 */

// Routes utilisateur
router.post('/submit', requireAuth, identityController.submitDocument);
router.get('/my-documents', requireAuth, identityController.getMyDocuments);
router.get('/verified-status', requireAuth, identityController.getVerifiedStatus);

// Routes admin
router.get('/pending', requireAuth, requireAdmin, identityController.getPendingDocuments);
router.post('/:documentId/approve', requireAuth, requireAdmin, identityController.approveDocument);
router.post('/:documentId/reject', requireAuth, requireAdmin, identityController.rejectDocument);

module.exports = router;
