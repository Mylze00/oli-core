/**
 * Routes Commandes (Orders) — avec Tracking System
 */
const express = require("express");
const router = express.Router();
const orderController = require("../controllers/order.controller");
const { requireRole } = require("../middlewares/auth.middleware");

/**
 * POST /orders - Créer une nouvelle commande
 */
router.post("/", orderController.create);

/**
 * POST /orders/quote - Devis exact (prix catalogue, livraison, montant en FC, frais Mobile Money)
 */
router.post("/quote", orderController.quote);

/**
 * GET /orders/delivery - Liste des commandes prêtes pour livraison
 */
router.get("/delivery", orderController.getDeliveryOrders);

/**
 * GET /orders - Liste des commandes de l'utilisateur
 */
router.get("/", orderController.getAll);

/**
 * GET /orders/:id - Détails d'une commande
 */
router.get("/:id", orderController.getById);

/**
 * GET /orders/:id/tracking - Timeline complète de suivi
 */
router.get("/:id/tracking", orderController.getTracking);

/**
 * GET /orders/:id/courier - Acheteur : position et parcours du livreur
 */
router.get("/:id/courier", async (req, res) => {
    try {
        const deliveryService = require("../services/delivery.service");
        res.json(await deliveryService.getCourierForBuyer(req.user.id, req.params.id));
    } catch (err) {
        res.status(err.status || 400).json({ error: err.message });
    }
});

/**
 * PATCH /orders/:id/status - Mettre à jour le statut (générique)
 */
// Réservé à l'admin : le vendeur passe par /api/seller/orders/:id/status
router.patch("/:id/status", requireRole('admin'), orderController.updateStatus);

/**
 * POST /orders/:id/prepare - Vendeur: marquer en préparation
 */
router.post("/:id/prepare", orderController.markProcessing);

/**
 * POST /orders/:id/ready - Vendeur: marquer comme prête
 */
router.post("/:id/ready", orderController.markReady);

/**
 * POST /orders/:id/verify-pickup - Livreur: valider récupération (code pickup)
 */
router.post("/:id/verify-pickup", orderController.verifyPickup);

/**
 * POST /orders/:id/verify-delivery - Acheteur: valider réception (code delivery)
 */
router.post("/:id/verify-delivery", orderController.verifyDelivery);

/**
 * POST /orders/:id/cancel - Annuler une commande
 */
router.post("/:id/cancel", orderController.cancel);

/**
 * POST /orders/:id/refund-request - Demander un remboursement (décision de l'administrateur)
 */
router.post("/:id/refund-request", orderController.requestRefund);

/**
 * POST /orders/:id/pay - Simuler le paiement (DEV)
 */
// Paiement simulé : jamais en production, une commande y passerait « payée » sans rien encaisser
router.post("/:id/pay", (req, res, next) => {
    if (process.env.NODE_ENV === 'production') {
        return res.status(403).json({ error: "Paiement simulé désactivé en production" });
    }
    next();
}, orderController.pay);

/**
 * POST /orders/:id/pay-mobile-money - Payer une commande en attente par Mobile Money (Unipesa)
 * Body: { phone }
 */
router.post("/:id/pay-mobile-money", orderController.payMobileMoney);

module.exports = router;
