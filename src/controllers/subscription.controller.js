const subscriptionService = require('../services/subscription.service');
const walletRepository = require('../repositories/wallet.repository');
const mmService = require('../services/mobile-money.service');

exports.upgradeAccount = async (req, res) => {
    try {
        const { plan, paymentMethod } = req.body;
        const userId = req.user.id;

        if (!plan || !paymentMethod) {
            return res.status(400).json({ message: "Plan et méthode de paiement requis." });
        }

        const result = await subscriptionService.upgradeSubscription(userId, plan, paymentMethod);

        res.status(200).json({
            message: "Abonnement activé avec succès !",
            subscription: result
        });
    } catch (error) {
        console.error("Upgrade Error:", error);
        res.status(400).json({ message: error.message || "Erreur lors de l'abonnement" });
    }
};

exports.getStatus = async (req, res) => {
    try {
        const status = await subscriptionService.checkSubscriptionStatus(req.user.id);
        res.status(200).json(status || { subscription_status: 'inactive' });
    } catch (error) {
        res.status(500).json({ message: "Erreur récupération statut" });
    }
};

/**
 * POST /api/subscription/request
 * Créer une demande de certification avec upload carte d'identité
 * Supporte 3 méthodes de paiement : mobile_money, wallet, card
 */
exports.createRequest = async (req, res) => {
    try {
        const userId = req.user.id;
        const { plan, document_type, payment_method, phone_number, card_number, expiry_date, cvv, cardholder_name } = req.body;

        if (!plan) {
            return res.status(400).json({ message: "Plan requis (certified ou enterprise)" });
        }

        if (!req.file) {
            return res.status(400).json({ message: "Photo de carte d'identité requise" });
        }

        if (!payment_method) {
            return res.status(400).json({ message: "Méthode de paiement requise" });
        }

        const amount = plan === 'enterprise' ? 39 : 4.99;
        let paymentReference = null;

        // ═══════════════════════════════════════════
        // TRAITEMENT DU PAIEMENT SELON LA MÉTHODE
        // ═══════════════════════════════════════════

        if (payment_method === 'orange_money' || payment_method === 'mtn') {
            // ── MOBILE MONEY ──
            if (!phone_number) {
                return res.status(400).json({ message: "Numéro de téléphone requis pour Mobile Money" });
            }

            const provider = payment_method === 'orange_money' ? 'orange' : 'mtn';
            const mmRes = await mmService.initiatePayment(provider, phone_number, amount);

            if (!mmRes.success || mmRes.status === 'failed') {
                return res.status(400).json({ message: mmRes.message || "Échec du paiement Mobile Money" });
            }

            paymentReference = mmRes.transaction_id;
            console.log(`📱 Paiement MM ${provider}: ${amount}$ via ${phone_number} → ref: ${paymentReference}`);

        } else if (payment_method === 'wallet') {
            // ── OLI WALLET ──
            const currentBalance = await walletRepository.getBalance(userId);
            if (currentBalance < amount) {
                return res.status(400).json({
                    message: `Solde insuffisant. Votre solde: ${currentBalance.toFixed(2)}$, montant requis: ${amount}$`
                });
            }

            const walletResult = await walletRepository.performDebit(
                userId,
                amount,
                {
                    type: 'payment',
                    provider: 'CERT_PAYMENT',
                    reference: `CERT_${Date.now()}`,
                    description: `Paiement certification ${plan}`,
                }
            );

            paymentReference = walletResult.transactionId || `CERT_WALLET_${Date.now()}`;
            console.log(`💰 Paiement Wallet: ${amount}$ débité du wallet user ${userId} → ref: ${paymentReference}`);

        } else if (payment_method === 'card') {
            // ── CARTE BANCAIRE (Simulation Stripe) ──
            if (!card_number || !expiry_date || !cvv) {
                return res.status(400).json({ message: "Informations de carte incomplètes" });
            }

            const cleanCardNumber = card_number.replace(/\s/g, '');
            if (!/^\d{16}$/.test(cleanCardNumber)) {
                return res.status(400).json({ message: "Numéro de carte invalide (16 chiffres requis)" });
            }
            if (!/^\d{3,4}$/.test(cvv)) {
                return res.status(400).json({ message: "CVV invalide" });
            }
            if (!/^\d{2}\/\d{2}$/.test(expiry_date)) {
                return res.status(400).json({ message: "Date d'expiration invalide (format MM/YY)" });
            }

            // Simulation: cartes commençant par 4000 = refusées
            if (cleanCardNumber.startsWith('4000')) {
                return res.status(400).json({ message: "Carte refusée - Fonds insuffisants (simulation)" });
            }

            paymentReference = `CARD_CERT_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
            console.log(`💳 Paiement Carte: ${amount}$ ****${cleanCardNumber.slice(-4)} → ref: ${paymentReference}`);

        } else {
            return res.status(400).json({ message: "Méthode de paiement non supportée" });
        }

        // ═══════════════════════════════
        // CRÉATION DE LA DEMANDE
        // ═══════════════════════════════

        const idCardUrl = req.file.path || req.file.secure_url || req.file.url;

        const result = await subscriptionService.createCertificationRequest(
            userId,
            plan,
            document_type || 'carte_identite',
            idCardUrl,
            payment_method,
            paymentReference
        );

        res.status(201).json({
            message: "Paiement réussi ! Demande de certification envoyée. Elle sera examinée sous 24-48h.",
            request: result,
            payment: {
                method: payment_method,
                amount,
                reference: paymentReference
            }
        });
    } catch (error) {
        console.error("❌ Certification Request Error:", error.message);
        console.error("Stack:", error.stack);
        console.error("Body received:", JSON.stringify(req.body));
        console.error("File received:", req.file ? JSON.stringify({ fieldname: req.file.fieldname, path: req.file.path, size: req.file.size }) : 'NO FILE');
        res.status(400).json({ message: error.message || "Erreur lors de la demande" });
    }
};

/**
 * GET /api/subscription/request/status
 * Vérifier l'état de la demande de certification
 */
exports.getRequestStatus = async (req, res) => {
    try {
        const request = await subscriptionService.getRequestStatus(req.user.id);
        res.json(request || { status: 'none' });
    } catch (error) {
        res.status(500).json({ message: "Erreur récupération statut demande" });
    }
};
