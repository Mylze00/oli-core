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

/**
 * POST /wallet/transfer
 * Transfert P2P (envoi cash via chat)
 */
const walletService = require('../services/wallet.service');

router.post('/transfer', async (req, res) => {
    const { receiverId, amount, currency } = req.body;

    if (!receiverId || !amount || amount <= 0) {
        return res.status(400).json({ error: "Données invalides (receiverId, amount requis)" });
    }

    try {
        const result = await walletService.transferToUser(
            req.user.id,
            parseInt(receiverId),
            parseFloat(amount),
            currency || 'USD'
        );
        res.json(result);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

module.exports = router;
