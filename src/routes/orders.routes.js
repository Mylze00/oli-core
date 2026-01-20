/**
 * Routes Commandes (Orders)
 */
const express = require("express");
const router = express.Router();
const orderController = require("../controllers/order.controller");

/**
 * POST /orders - Créer une nouvelle commande
 */
router.post("/", orderController.create);

/**
 * GET /orders - Liste des commandes de l'utilisateur
 */
router.get("/", orderController.getAll);

/**
 * GET /orders/:id - Détails d'une commande
 */
router.get("/:id", orderController.getById);

/**
 * PATCH /orders/:id/status - Mettre à jour le statut
 */
router.patch("/:id/status", orderController.updateStatus);

/**
 * POST /orders/:id/cancel - Annuler une commande
 */
router.post("/:id/cancel", orderController.cancel);

/**
 * POST /orders/:id/pay - Simuler le paiement (DEV)
 */
router.post("/:id/pay", orderController.pay);

module.exports = router;
