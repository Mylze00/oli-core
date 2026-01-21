/**
 * Routes Boutiques Oli
 * Gestion des boutiques virtuelles
 */
const express = require('express');
const router = express.Router();
const shopRepo = require('../repositories/shop.repository');
const { requireAuth, optionalAuth } = require('../middlewares/auth.middleware');
const { genericUpload } = require('../config/upload');
const { BASE_URL } = require('../config');

// Helper pour les URLs d'images
const formatShopUrls = (shop) => {
    if (!shop) return null;
    return {
        ...shop,
        logo_url: shop.logo_url && !shop.logo_url.startsWith('http')
            ? `${BASE_URL}/uploads/${shop.logo_url}`
            : shop.logo_url,
        banner_url: shop.banner_url && !shop.banner_url.startsWith('http')
            ? `${BASE_URL}/uploads/${shop.banner_url}`
            : shop.banner_url,
        owner_avatar: shop.owner_avatar && !shop.owner_avatar.startsWith('http')
            ? `${BASE_URL}/uploads/${shop.owner_avatar}`
            : shop.owner_avatar,
    };
};

/**
 * GET /shops
 * Liste des boutiques (Public)
 */
router.get('/', async (req, res) => {
    try {
        const { limit, offset, category, search } = req.query;
        const shops = await shopRepo.findAll(limit, offset, category, search);
        res.json(shops.map(formatShopUrls));
    } catch (err) {
        console.error("Erreur GET /shops:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /shops/my-shops
 * Boutiques de l'utilisateur connecté
 */
router.get('/my-shops', requireAuth, async (req, res) => {
    try {
        const shops = await shopRepo.findByOwnerId(req.user.id);
        res.json(shops.map(formatShopUrls));
    } catch (err) {
        console.error("Erreur GET /shops/my-shops:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /shops/verified
 * Boutiques vérifiées ou Entreprises (Carousel Accueil)
 */
router.get('/verified', async (req, res) => {
    try {
        const { limit } = req.query;
        const shops = await shopRepo.findVerified(limit);
        res.json(shops.map(formatShopUrls));
    } catch (err) {
        console.error("Erreur GET /shops/verified:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /shops/:id
 * Détails d'une boutique
 */
router.get('/:id', async (req, res) => {
    try {
        const shop = await shopRepo.findById(req.params.id);
        if (!shop) {
            return res.status(404).json({ error: "Boutique introuvable" });
        }
        res.json(formatShopUrls(shop));
    } catch (err) {
        console.error("Erreur GET /shops/:id:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * POST /shops
 * Créer une boutique
 */
router.post('/', requireAuth, genericUpload.fields([
    { name: 'logo', maxCount: 1 },
    { name: 'banner', maxCount: 1 }
]), async (req, res) => {
    try {
        const { name, description, category, location } = req.body;

        if (!name) {
            return res.status(400).json({ error: "Le nom de la boutique est requis" });
        }

        const logoFilename = req.files['logo'] ? req.files['logo'][0].filename : null;
        const bannerFilename = req.files['banner'] ? req.files['banner'][0].filename : null;

        const newShop = await shopRepo.create({
            owner_id: req.user.id,
            name,
            description,
            category,
            location,
            logo_url: logoFilename,
            banner_url: bannerFilename
        });

        res.status(201).json(formatShopUrls(newShop));
    } catch (err) {
        console.error("Erreur POST /shops:", err);
        res.status(500).json({ error: "Erreur création boutique" });
    }
});

/**
 * PATCH /shops/:id
 * Modifier une boutique
 */
router.patch('/:id', requireAuth, genericUpload.fields([
    { name: 'logo', maxCount: 1 },
    { name: 'banner', maxCount: 1 }
]), async (req, res) => {
    try {
        const { id } = req.params;
        const shop = await shopRepo.findById(id);

        if (!shop) {
            return res.status(404).json({ error: "Boutique introuvable" });
        }

        if (shop.owner_id !== req.user.id && !req.user.is_admin) {
            return res.status(403).json({ error: "Non autorisé" });
        }

        const updates = { ...req.body };

        if (req.files['logo']) {
            updates.logo_url = req.files['logo'][0].filename;
        }
        if (req.files['banner']) {
            updates.banner_url = req.files['banner'][0].filename;
        }

        const updatedShop = await shopRepo.update(id, updates);
        res.json(formatShopUrls(updatedShop));

    } catch (err) {
        console.error("Erreur PATCH /shops/:id:", err);
        res.status(500).json({ error: "Erreur modification" });
    }
});

/**
 * DELETE /shops/:id
 * Supprimer une boutique
 */
router.delete('/:id', requireAuth, async (req, res) => {
    try {
        const { id } = req.params;
        const shop = await shopRepo.findById(id);

        if (!shop) {
            return res.status(404).json({ error: "Boutique introuvable" });
        }

        if (shop.owner_id !== req.user.id && !req.user.is_admin) {
            return res.status(403).json({ error: "Non autorisé" });
        }

        await shopRepo.deleteById(id);
        res.json({ success: true, message: "Boutique supprimée" });
    } catch (err) {
        console.error("Erreur DELETE /shops/:id:", err);
        res.status(500).json({ error: "Erreur suppression" });
    }
});

module.exports = router;
