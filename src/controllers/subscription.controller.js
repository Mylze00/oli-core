const subscriptionService = require('../services/subscription.service');

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
 */
exports.createRequest = async (req, res) => {
    try {
        const userId = req.user.id;
        const { plan, document_type, payment_method } = req.body;

        if (!plan) {
            return res.status(400).json({ message: "Plan requis (certified ou enterprise)" });
        }

        if (!req.file) {
            return res.status(400).json({ message: "Photo de carte d'identité requise" });
        }

        if (!payment_method) {
            return res.status(400).json({ message: "Méthode de paiement requise" });
        }

        // Simuler le paiement
        console.log(`[PAIEMENT CERTIFICATION] $${plan === 'enterprise' ? 39 : 4.99} via ${payment_method} pour user ${userId}`);

        // URL de l'image uploadée (Cloudinary ou local)
        const idCardUrl = req.file.path || req.file.secure_url || req.file.url;

        const result = await subscriptionService.createCertificationRequest(
            userId,
            plan,
            document_type || 'carte_identite',
            idCardUrl
        );

        res.status(201).json({
            message: "Demande de certification envoyée ! Elle sera examinée sous 24-48h.",
            request: result
        });
    } catch (error) {
        console.error("Certification Request Error:", error);
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
