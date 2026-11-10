const orderService = require('../services/order.service');
const refundService = require('../services/refund.service');

exports.create = async (req, res) => {
    try {
        const io = req.app.get('io');
        const order = await orderService.createOrder(req.user.id, req.body, io);
        res.status(201).json({ message: "Commande créée", order });
    } catch (error) {
        console.error("Erreur création commande:", error);
        if (error.status === 503) {
            return res.status(503).json({ error: error.message });
        }
        // Erreurs métier (produit introuvable, quantité invalide, etc.) : 400 avec message clair
        if (error.status === 400 || error.message === "Items requis" || error.message.startsWith("Chaque item")) {
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

exports.getDeliveryOrders = async (req, res) => {
    try {
        const orders = await orderService.getDeliveryOrders();
        res.json(orders);
    } catch (error) {
        console.error("Erreur récupération commandes livraison:", error);
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
        if (error.status === 409) {
            return res.status(409).json({ error: error.message });
        }
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

exports.requestRefund = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        if (!Number.isInteger(orderId)) {
            return res.status(400).json({ error: "Commande invalide" });
        }
        const request = await refundService.requestRefund(
            req.user.id, orderId, req.body?.reason, req.body?.description, req.app.get('io')
        );
        res.status(201).json({ message: "Demande de remboursement envoyée", request });
    } catch (error) {
        console.error("Erreur demande de remboursement:", error);
        res.status(error.status || 500).json({ error: error.status ? error.message : "Erreur serveur" });
    }
};

exports.pay = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { paymentMethod } = req.body;
        const io = req.app.get('io');
        // Contrôle d'accès : seul l'acheteur peut régler sa commande (sinon 404 pour ne pas révéler l'existence)
        const pool = require('../config/db');
        const { rows } = await pool.query(
            'SELECT user_id, payment_status FROM orders WHERE id = $1',
            [orderId]
        );
        if (rows.length === 0 || Number(rows[0].user_id) !== Number(req.user.id)) {
            return res.status(404).json({ error: "Commande non trouvée" });
        }
        if (rows[0].payment_status === 'completed') {
            return res.status(409).json({ error: "Commande déjà payée" });
        }

        const order = await orderService.simulatePayment(orderId, paymentMethod, io);
        res.json({ message: "Paiement effectué", order });
    } catch (error) {
        console.error("Erreur paiement:", error);
        if (error.message === "Commande non trouvée") {
            return res.status(404).json({ error: "Commande non trouvée" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

// --- TRACKING ENDPOINTS ---

/**
 * POST /orders/:id/prepare — vendeur met en préparation
 */
exports.markProcessing = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const io = req.app.get('io');
        const order = await orderService.markProcessing(orderId, req.user.id, io);
        res.json({ message: "Commande en préparation", order });
    } catch (error) {
        console.error("Erreur markProcessing:", error);
        res.status(error.message.includes('non trouvée') ? 404 : 400).json({ error: error.message });
    }
};

/**
 * POST /orders/:id/ready — vendeur marque comme prête
 */
exports.markReady = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const io = req.app.get('io');
        const order = await orderService.markReady(orderId, req.user.id, io);
        res.json({ message: "Commande prête pour expédition", order });
    } catch (error) {
        console.error("Erreur markReady:", error);
        res.status(error.message.includes('non trouvée') ? 404 : 400).json({ error: error.message });
    }
};

/**
 * POST /orders/:id/verify-pickup — livreur valide la récupération
 */
exports.verifyPickup = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { code } = req.body;
        const io = req.app.get('io');
        const order = await orderService.verifyPickup(orderId, code, req.user.id, io);
        res.json({ message: "Pickup validé, colis en route", order });
    } catch (error) {
        console.error("Erreur verifyPickup:", error);
        if (error.status === 409) {
            return res.status(409).json({ error: error.message });
        }
        if (error.message.includes('Accès non autorisé')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message.includes('invalide')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(error.message.includes('non trouvée') ? 404 : 500).json({ error: error.message });
    }
};

/**
 * POST /orders/:id/verify-delivery — acheteur valide la réception
 */
exports.verifyDelivery = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { code } = req.body;
        const io = req.app.get('io');
        const order = await orderService.verifyDelivery(orderId, code, req.user.id, io);
        res.json({ message: "Livraison confirmée", order });
    } catch (error) {
        console.error("Erreur verifyDelivery:", error);
        if (error.status === 409) {
            return res.status(409).json({ error: error.message });
        }
        if (error.message.includes('invalide')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(error.message.includes('non trouvée') ? 404 : 500).json({ error: error.message });
    }
};

/**
 * GET /orders/:id/tracking — timeline complète
 */
exports.getTracking = async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const tracking = await orderService.getOrderTracking(orderId, req.user.id);
        res.json(tracking);
    } catch (error) {
        console.error("Erreur tracking:", error);
        if (error.message.includes('non autorisé')) {
            return res.status(403).json({ error: error.message });
        }
        res.status(error.message.includes('non trouvée') ? 404 : 500).json({ error: error.message });
    }
};
