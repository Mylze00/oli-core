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
