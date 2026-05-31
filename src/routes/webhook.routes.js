const express = require('express');
const unipesaWebhookController = require('../controllers/unipesa.controller');

const router = express.Router();

/**
 * Routes de Webhooks Unipesa
 * Ces endpoints doivent rester PUBLICS (aucun middleware auth).
 * La sécurité est assurée via la vérification de la signature HMAC-SHA512.
 */

// Callback pour les dépôts C2B (client → OLI Wallet)
router.post('/unipesa/deposit', unipesaWebhookController.handleDeposit);

// Callback pour les retraits B2C (OLI Wallet → client)
router.post('/unipesa/withdrawal', unipesaWebhookController.handleWithdrawal);

// Callback pour le paiement direct des commandes (C2B)
router.post('/unipesa/order_payment', unipesaWebhookController.handleOrderPayment);


module.exports = router;
