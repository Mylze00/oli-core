const walletService = require('../services/wallet.service');

exports.getBalance = async (req, res) => {
    try {
        const balance = await walletService.getBalance(req.user.id);
        res.json({ balance, currency: 'USD' });
    } catch (err) {
        console.error("Erreur récupération solde:", err);
        res.status(500).json({ error: "Erreur récupération solde" });
    }
};

exports.getHistory = async (req, res) => {
    try {
        const history = await walletService.getHistory(req.user.id);
        res.json(history);
    } catch (err) {
        console.error("Erreur historique:", err);
        res.status(500).json({ error: "Erreur historique" });
    }
};

exports.deposit = async (req, res) => {
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
};

exports.withdraw = async (req, res) => {
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
};

exports.depositCard = async (req, res) => {
    const { amount, cardNumber, expiryDate, cvv, cardholderName } = req.body;

    if (!amount || amount <= 0) {
        return res.status(400).json({ error: "Montant invalide" });
    }

    try {
        const cardInfo = {
            cardNumber,
            expiryDate,
            cvv,
            cardholderName: cardholderName || 'Card Holder'
        };

        const result = await walletService.depositByCard(req.user.id, parseFloat(amount), cardInfo);
        res.json(result);
    } catch (err) {
        console.error("Erreur dépôt carte:", err);
        res.status(400).json({ error: err.message });
    }
};
