const express = require('express');
const onafriqWebhookController = require('../controllers/onafriq.controller');

const router = express.Router();

/**
 * Routes de Webhooks
 * Attention: Ces endpoints doivent être publics pour qu'Onafriq puisse les appeler.
 * Il ne faut PAS y mettre de middleware d'authentification utilisateur type `auth()`.
 * La sécurité doit se faire via vérification de signature ou IP whitelist (si Onafriq le permet).
 */

// Callback pour les dépôts (Collections)
router.post('/onafriq/collections', onafriqWebhookController.handleCollection);

// Callback pour les retraits (Disbursements)
router.post('/onafriq/disbursements', onafriqWebhookController.handleDisbursement);

module.exports = router;
