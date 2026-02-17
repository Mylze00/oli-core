/**
 * Routes Mini-App Livreur
 */
const express = require('express');
const router = express.Router();
const deliveryService = require('../services/delivery.service');
const { requireAuth } = require('../middlewares/auth.middleware');

// Middleware spécifique : doit être livreur
const requireDeliverer = (req, res, next) => {
    if (!req.user.is_deliverer) {
        return res.status(403).json({ error: "Accès réservé aux livreurs" });
    }
    next();
};

/**
 * GET /delivery/available
 * Liste des commandes en attente de prise en charge
 */
router.get('/available', requireAuth, requireDeliverer, async (req, res) => {
    try {
        const deliveries = await deliveryService.getAvailableDeliveries(req.user);
        res.json(deliveries);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /delivery/my-tasks
 * Mes livraisons en cours
 */
router.get('/my-tasks', requireAuth, requireDeliverer, async (req, res) => {
    try {
        const deliveries = await deliveryService.getMyDeliveries(req.user);
        res.json(deliveries);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

/**
 * POST /delivery/:id/accept
 * Accepter une course
 */
router.post('/:id/accept', requireAuth, requireDeliverer, async (req, res) => {
    try {
        const delivery = await deliveryService.acceptDelivery(req.user, req.params.id);
        res.json({ success: true, delivery });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

/**
 * POST /delivery/:id/status
 * Mettre à jour statut + GPS
 */
router.post('/:id/status', requireAuth, requireDeliverer, async (req, res) => {
    const { status, lat, lng } = req.body;
    try {
        const delivery = await deliveryService.updateStatus(req.user, req.params.id, status, lat, lng);
        res.json({ success: true, delivery });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

/**
 * POST /delivery/:id/verify
 * Vérifier le code QR
 */
router.post('/:id/verify', requireAuth, requireDeliverer, async (req, res) => {
    const { code } = req.body;
    try {
        const delivery = await deliveryService.verifyDelivery(req.user, req.params.id, code);
        res.json({ success: true, delivery });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});


// ─── WALLET LIVREUR ──────────────────────────────────────────

const walletService = require('../services/wallet.service');

/**
 * GET /delivery/wallet/balance
 * Solde du wallet du livreur
 */
router.get('/wallet/balance', requireAuth, requireDeliverer, async (req, res) => {
    try {
        const balance = await walletService.getBalance(req.user.id);
        res.json({ balance, currency: 'USD' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /delivery/wallet/transactions
 * Historique des transactions du livreur
 */
router.get('/wallet/transactions', requireAuth, requireDeliverer, async (req, res) => {
    try {
        const history = await walletService.getHistory(req.user.id);
        res.json(history);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

/**
 * POST /delivery/wallet/withdraw
 * Retrait vers Mobile Money
 */
router.post('/wallet/withdraw', requireAuth, requireDeliverer, async (req, res) => {
    const { amount, provider, phoneNumber } = req.body;

    if (!amount || amount <= 0 || !provider || !phoneNumber) {
        return res.status(400).json({ error: "Données invalides (amount, provider, phoneNumber requis)" });
    }

    try {
        const result = await walletService.withdraw(req.user.id, parseFloat(amount), provider, phoneNumber);
        res.json(result);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

module.exports = router;
