const express = require("express");
const orderRepo = require("../repositories/order.repository");

const router = express.Router();

/**
 * POST /orders - Créer une nouvelle commande
 */
router.post("/", async (req, res) => {
    try {
        const userId = req.user.id; // Vient du middleware verifyToken
        const { items, deliveryAddress, paymentMethod, deliveryFee } = req.body;

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ error: "Items requis" });
        }

        // Validation des items
        for (const item of items) {
            if (!item.productId || !item.productName || !item.price || !item.quantity) {
                return res.status(400).json({ error: "Chaque item doit avoir productId, productName, price et quantity" });
            }
        }

        const order = await orderRepo.createOrder(
            userId,
            items,
            deliveryAddress || null,
            paymentMethod || 'wallet',
            parseFloat(deliveryFee) || 0
        );

        res.status(201).json({ message: "Commande créée", order });
    } catch (error) {
        console.error("Erreur création commande:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /orders - Liste des commandes de l'utilisateur
 */
router.get("/", async (req, res) => {
    try {
        const userId = req.user.id;
        const orders = await orderRepo.getOrdersByUser(userId);
        res.json(orders);
    } catch (error) {
        console.error("Erreur récupération commandes:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /orders/:id - Détails d'une commande
 */
router.get("/:id", async (req, res) => {
    try {
        const userId = req.user.id;
        const orderId = parseInt(req.params.id);

        const order = await orderRepo.getOrderById(orderId, userId);

        if (!order) {
            return res.status(404).json({ error: "Commande non trouvée" });
        }

        res.json(order);
    } catch (error) {
        console.error("Erreur récupération commande:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * PATCH /orders/:id/status - Mettre à jour le statut
 */
router.patch("/:id/status", async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { status } = req.body;

        const validStatuses = ['pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: "Statut invalide" });
        }

        const order = await orderRepo.updateOrderStatus(orderId, status);

        if (!order) {
            return res.status(404).json({ error: "Commande non trouvée" });
        }

        res.json({ message: "Statut mis à jour", order });
    } catch (error) {
        console.error("Erreur mise à jour statut:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * POST /orders/:id/cancel - Annuler une commande
 */
router.post("/:id/cancel", async (req, res) => {
    try {
        const userId = req.user.id;
        const orderId = parseInt(req.params.id);

        const order = await orderRepo.cancelOrder(orderId, userId);

        if (!order) {
            return res.status(400).json({ error: "Impossible d'annuler cette commande" });
        }

        res.json({ message: "Commande annulée", order });
    } catch (error) {
        console.error("Erreur annulation:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * POST /orders/:id/pay - Simuler le paiement (DEV)
 */
router.post("/:id/pay", async (req, res) => {
    try {
        const orderId = parseInt(req.params.id);
        const { paymentMethod } = req.body;

        // En production: intégrer Stripe / Mobile Money ici
        const order = await orderRepo.updatePaymentStatus(orderId, 'completed');

        if (!order) {
            return res.status(404).json({ error: "Commande non trouvée" });
        }

        res.json({ message: "Paiement effectué", order });
    } catch (error) {
        console.error("Erreur paiement:", error);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

module.exports = router;
