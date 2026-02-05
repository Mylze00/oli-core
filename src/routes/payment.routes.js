/**
 * Routes de Paiement
 */
const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');

// Créer une intention de paiement
router.post('/create-payment-intent', paymentController.createPaymentIntent);

// Webhook (simulation)
router.post('/webhook', paymentController.handleWebhook);

module.exports = router;
