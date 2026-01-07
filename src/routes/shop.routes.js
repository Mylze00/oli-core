const express = require("express");
const requireAuth = require("../middlewares/auth.middleware");
const shopService = require("../services/shop.service");

const router = express.Router();

// Créer boutique
router.post("/", requireAuth, async (req, res) => {
  try {
    const { name, description } = req.body;
    const shop = await shopService.createShop(req.user.sub, name, description);
    res.json(shop);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create shop" });
  }
});

// Lister boutiques utilisateur
router.get("/", requireAuth, async (req, res) => {
  try {
    const shops = await shopService.listUserShops(req.user.sub);
    res.json(shops);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch shops" });
  }
});

module.exports = router;
