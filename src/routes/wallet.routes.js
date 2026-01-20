/**
 * Routes Wallet et Paiements
 */
const express = require('express');
const router = express.Router();
const walletController = require('../controllers/wallet.controller');

/**
 * GET /wallet/balance
 * Solde actuel
 */
router.get('/balance', walletController.getBalance);

/**
 * GET /wallet/transactions
 * Historique
 */
router.get('/transactions', walletController.getHistory);

/**
 * POST /wallet/deposit
 * Dépôt via Mobile Money
 */
router.post('/deposit', walletController.deposit);

/**
 * POST /wallet/withdraw
 * Retrait vers Mobile Money
 */
router.post('/withdraw', walletController.withdraw);

/**
 * POST /wallet/deposit-card
 * Dépôt via Carte Bancaire
 */
router.post('/deposit-card', walletController.depositCard);

module.exports = router;
