const orderService = require('../services/order.service');

exports.create = async (req, res) => {
    try {
        const order = await orderService.createOrder(req.user.id, req.body);
        res.status(201).json({ message: "Commande créée", order });
    } catch (error) {
        console.error("Erreur création commande:", error);
        if (error.message === "Items requis" || error.message.startsWith("Chaque item")) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getAll = async (req, res) => {
    try {
        const orders = await orderService.getUserOrders(req.user.id);
        res.json(orders);
    } catch (error) {
        console.error("Erreur récupération commandes:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getById = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const order = await orderService.getOrderById(req.user.id, orderId);
        res.json(order);
    } catch (error) {
        console.error("Erreur récupération commande:", error);
        if (error.message === "Commande non trouvée") {
            return res.status(404).json({ error: "Commande non trouvée" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.updateStatus = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { status } = req.body;
        const order = await orderService.updateStatus(orderId, status);
        res.json({ message: "Statut mis à jour", order });
    } catch (error) {
        console.error("Erreur mise à jour statut:", error);
        if (error.message === "Statut invalide") {
            return res.status(400).json({ error: "Statut invalide" });
        }
        if (error.message === "Commande non trouvée") {
            return res.status(404).json({ error: "Commande non trouvée" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.cancel = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const order = await orderService.cancelOrder(req.user.id, orderId);
        res.json({ message: "Commande annulée", order });
    } catch (error) {
        console.error("Erreur annulation:", error);
        if (error.message.startsWith("Impossible d'annuler")) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.pay = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { paymentMethod } = req.body;
        const order = await orderService.simulatePayment(orderId, paymentMethod);
        res.json({ message: "Paiement effectué", order });
    } catch (error) {
        console.error("Erreur paiement:", error);
        if (error.message === "Commande non trouvée") {
            return res.status(404).json({ error: "Commande non trouvée" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};
