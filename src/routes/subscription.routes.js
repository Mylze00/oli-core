const express = require('express');
const router = express.Router();
const subscriptionController = require('../controllers/subscription.controller');
const { requireAuth } = require('../middlewares/auth.middleware');
const { genericUpload } = require('../config/upload');

// Routes protégées par Auth
router.use(requireAuth);

// Legacy: upgrade direct (gardé pour compatibilité)
router.post('/upgrade', subscriptionController.upgradeAccount);
router.get('/status', subscriptionController.getStatus);

// Nouvelle certification avec upload carte d'identité
router.post('/request', genericUpload.single('id_card'), subscriptionController.createRequest);
router.get('/request/status', subscriptionController.getRequestStatus);

module.exports = router;
