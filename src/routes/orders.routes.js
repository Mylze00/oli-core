/**
 * Routes Commandes (Orders) — avec Tracking System
 */
const express = require("express");
const router = express.Router();
const orderController = require("../controllers/order.controller");

/**
 * POST /orders - Créer une nouvelle commande
 */
router.post("/", orderController.create);

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
 * PATCH /orders/:id/status - Mettre à jour le statut (générique)
 */
router.patch("/:id/status", orderController.updateStatus);

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
 * POST /orders/:id/pay - Simuler le paiement (DEV)
 */
router.post("/:id/pay", orderController.pay);

module.exports = router;
