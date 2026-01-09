/**
 * Routes Wallet et Paiements
 */
const express = require('express');
const router = express.Router();
const walletService = require('../services/wallet.service');

/**
 * GET /wallet/balance
 * Solde actuel
 */
router.get('/balance', async (req, res) => {
    try {
        const balance = await walletService.getBalance(req.user.id);
        res.json({ balance, currency: 'USD' });
    } catch (err) {
        res.status(500).json({ error: "Erreur récupération solde" });
    }
});

/**
 * GET /wallet/transactions
 * Historique
 */
router.get('/transactions', async (req, res) => {
    try {
        const history = await walletService.getHistory(req.user.id);
        res.json(history);
    } catch (err) {
        res.status(500).json({ error: "Erreur historique" });
    }
});

/**
 * POST /wallet/deposit
 * Dépôt via Mobile Money
 */
router.post('/deposit', async (req, res) => {
    const { amount, provider, phoneNumber } = req.body;

    if (!amount || amount <= 0 || !provider || !phoneNumber) {
        return res.status(400).json({ error: "Données invalides (amount, provider, phoneNumber requis)" });
    }

    try {
        const result = await walletService.deposit(req.user.id, parseFloat(amount), provider, phoneNumber);
        res.json(result);
    } catch (err) {
        console.error("Erreur dépôt:", err);
        res.status(400).json({ error: err.message });
    }
});

/**
 * POST /wallet/withdraw
 * Retrait vers Mobile Money
 */
router.post('/withdraw', async (req, res) => {
    const { amount, provider, phoneNumber } = req.body;

    if (!amount || amount <= 0 || !provider || !phoneNumber) {
        return res.status(400).json({ error: "Données invalides" });
    }

    try {
        const result = await walletService.withdraw(req.user.id, parseFloat(amount), provider, phoneNumber);
        res.json(result);
    } catch (err) {
        console.error("Erreur retrait:", err);
        res.status(400).json({ error: err.message });
    }
});

module.exports = router;
