/**
 * Wallet Controller OLI
 * Routes : GET /wallet/balance, GET /wallet/transactions,
 *          POST /wallet/deposit, POST /wallet/withdraw,
 *          POST /wallet/deposit-card, POST /wallet/transfer
 */
const walletService = require('../services/wallet.service');

// ─── Lecture ────────────────────────────────────────────────────────────────

exports.getBalance = async (req, res) => {
    try {
        const balance = await walletService.getBalance(req.user.id);
        res.json({
            balance,
            formattedBalance: `${balance.toFixed(0)} FC`,
            currency: 'FC',
        });
    } catch (err) {
        console.error('Erreur solde wallet:', err.message);
        res.status(500).json({ error: 'Impossible de récupérer le solde' });
    }
};

exports.getHistory = async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 30, 100);
        const history = await walletService.getHistory(req.user.id, limit);
        res.json({ transactions: history, count: history.length });
    } catch (err) {
        console.error('Erreur historique wallet:', err.message);
        res.status(500).json({ error: "Impossible de récupérer l'historique" });
    }
};

// ─── Recharge Mobile Money ───────────────────────────────────────────────────

exports.deposit = async (req, res) => {
    const { amount, provider, phoneNumber } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ error: 'Montant invalide' });
    }
    if (!provider || !phoneNumber) {
        return res.status(400).json({ error: 'Opérateur et numéro de téléphone requis' });
    }

    try {
        const result = await walletService.deposit(
            req.user.id,
            parseFloat(amount),
            provider,
            phoneNumber
        );
        res.json({
            success: true,
            message: `Recharge de ${parseFloat(amount).toFixed(0)} FC effectuée`,
            newBalance: result.balanceAfter,
            transactionId: result.transactionId,
        });
    } catch (err) {
        console.error('Erreur dépôt Mobile Money:', err.message);
        res.status(400).json({ error: err.message });
    }
};

// ─── Recharge Carte bancaire ─────────────────────────────────────────────────

exports.depositCard = async (req, res) => {
    const { amount, cardNumber, expiryDate, cvv, cardholderName } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ error: 'Montant invalide' });
    }

    try {
        const cardInfo = { cardNumber, expiryDate, cvv, cardholderName: cardholderName || 'Card Holder' };
        const result = await walletService.depositByCard(req.user.id, parseFloat(amount), cardInfo);
        res.json({
            success: true,
            message: `Recharge de ${parseFloat(amount).toFixed(0)} FC par carte effectuée`,
            newBalance: result.balanceAfter,
            transactionId: result.transactionId,
        });
    } catch (err) {
        console.error('Erreur dépôt carte:', err.message);
        res.status(400).json({ error: err.message });
    }
};

// ─── Retrait Mobile Money ────────────────────────────────────────────────────

exports.withdraw = async (req, res) => {
    const { amount, provider, phoneNumber } = req.body;

    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ error: 'Montant invalide' });
    }
    if (!provider || !phoneNumber) {
        return res.status(400).json({ error: 'Opérateur et numéro de téléphone requis' });
    }

    try {
        const result = await walletService.withdraw(
            req.user.id,
            parseFloat(amount),
            provider,
            phoneNumber
        );
        res.json({
            success: true,
            message: `Retrait de ${parseFloat(amount).toFixed(0)} FC effectué`,
            newBalance: result.balanceAfter,
            transactionId: result.transactionId,
        });
    } catch (err) {
        console.error('Erreur retrait:', err.message);
        res.status(400).json({ error: err.message });
    }
};

// ─── Transfert P2P ───────────────────────────────────────────────────────────

exports.transfer = async (req, res) => {
    // Le frontend envoie 'recipient_phone' au lieu de 'receiverId'
    const { receiverId, recipient_phone, amount, currency } = req.body;

    if (!receiverId && !recipient_phone) {
        return res.status(400).json({ error: 'Identifiant du destinataire requis' });
    }
    if (!amount || parseFloat(amount) <= 0) {
        return res.status(400).json({ error: 'Montant invalide' });
    }

    try {
        let finalReceiverId = receiverId;

        if (!finalReceiverId && recipient_phone) {
            const userRepository = require('../repositories/user.repository');
            const user = await userRepository.findByIdentifier(recipient_phone);
            if (!user) {
                return res.status(404).json({ error: 'Destinataire introuvable avec cet identifiant' });
            }
            finalReceiverId = user.id;
        }

        const result = await walletService.transferToUser(
            req.user.id,
            parseInt(finalReceiverId),
            parseFloat(amount),
            currency || 'FC'
        );
        res.json({
            success: true,
            message: `${result.amountUSD.toFixed(0)} FC envoyé avec succès`,
            ...result,
        });
    } catch (err) {
        console.error('Erreur transfert P2P:', err.message);
        res.status(400).json({ error: err.message });
    }
};

// ─── Résolution Destinataire ──────────────────────────────────────────────────

exports.resolveRecipient = async (req, res) => {
    const { identifier } = req.query;

    if (!identifier) {
        return res.status(400).json({ error: 'Identifiant requis' });
    }

    // Ne pas autoriser la recherche de soi-même
    if (identifier === req.user.phone || identifier === req.user.pseudo || identifier === req.user.id_oli) {
        return res.status(400).json({ error: 'Vous ne pouvez pas vous envoyer des fonds à vous-même' });
    }

    try {
        const userRepository = require('../repositories/user.repository');
        const user = await userRepository.findByIdentifier(identifier);
        
        if (!user) {
            return res.status(404).json({ error: 'Destinataire introuvable' });
        }
        
        if (user.id === req.user.id) {
            return res.status(400).json({ error: 'Vous ne pouvez pas vous envoyer des fonds à vous-même' });
        }

        res.json({
            success: true,
            user: {
                name: user.name,
                phone: user.phone,
            }
        });
    } catch (err) {
        console.error('Erreur resolveRecipient:', err.message);
        res.status(500).json({ error: 'Erreur lors de la recherche du destinataire' });
    }
};
