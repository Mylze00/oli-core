const express = require('express');
const router = express.Router();
const subscriptionController = require('../controllers/subscription.controller');
const { requireAuth } = require('../middlewares/auth.middleware');

// Routes protégées par Auth
router.use(requireAuth);

router.post('/upgrade', subscriptionController.upgradeAccount);
router.get('/status', subscriptionController.getStatus);

module.exports = router;
