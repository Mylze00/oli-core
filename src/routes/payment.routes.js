/**
 * Routes de Paiement
 */
const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { verifyStripeWebhook } = require('../middlewares/stripe-signature.middleware');

// Créer une intention de paiement
router.post('/create-payment-intent', paymentController.createPaymentIntent);

// Webhook Stripe : signature obligatoire (les appels non signés sont refusés)
router.post('/webhook', verifyStripeWebhook, paymentController.handleWebhook);

module.exports = router;
