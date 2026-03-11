/**
 * Routes Wallet OLI
 */
const express = require('express');
const router = express.Router();
const walletController = require('../controllers/wallet.controller');

/** GET /wallet/balance — Solde actuel */
router.get('/balance', walletController.getBalance);

/** GET /wallet/transactions — Historique (query: ?limit=30) */
router.get('/transactions', walletController.getHistory);

/** POST /wallet/deposit — Recharge via Mobile Money
 *  Body: { amount, provider, phoneNumber }
 */
router.post('/deposit', walletController.deposit);

/** POST /wallet/deposit-card — Recharge via Carte
 *  Body: { amount, cardNumber, expiryDate, cvv, cardholderName? }
 */
router.post('/deposit-card', walletController.depositCard);

/** POST /wallet/withdraw — Retrait vers Mobile Money
 *  Body: { amount, provider, phoneNumber }
 */
router.post('/withdraw', walletController.withdraw);

/** POST /wallet/transfer — Transfert P2P
 *  Body: { receiverId, amount, currency? ('USD'|'FC') }
 */
router.post('/transfer', walletController.transfer);

module.exports = router;
