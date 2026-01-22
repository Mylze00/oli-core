/**
 * Routes Produits Oli
 * Marketplace - Catalogue, Upload, Gestion
 */
const express = require('express');
const router = express.Router();
const productController = require('../controllers/product.controller');
const { productUpload } = require('../config/upload');

// --- Routes Publiques ---

/**
 * GET /products/good-deals
 * Récupère les bons deals (Public)
 */
router.get('/good-deals', async (req, res) => {
    try {
        const productRepo = require('../repositories/product.repository');
        const products = await productRepo.findGoodDeals(10);
        res.json(products);
    } catch (err) {
        console.error('Erreur GET /products/good-deals:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /products/featured
 * Produits de l'administrateur uniquement (pour page Accueil)
 */
router.get('/featured', productController.getFeatured);

/**
 * GET /products/top-sellers
 * Meilleurs vendeurs du marketplace
 */
router.get('/top-sellers', productController.getTopSellers);

/**
 * GET /products/verified-shops
 * Produits des grands magasins vérifiés
 */
router.get('/verified-shops', productController.getVerifiedShops);

/**
 * GET /products
 * Liste tous les produits actifs (avec filtres)
 */
router.get('/', productController.getAll);

/**
 * GET /products/:id
 * Détails d'un produit
 */
router.get('/:id', productController.getById);


// --- Routes Authentifiées (User via Middleware global ou spécifique) ---

/**
 * POST /products/upload
 * Créer un nouveau produit
 */
router.post('/upload',
    (req, res, next) => {
        console.log("🛠️ Tentative d'upload - Passage vers Multer...");
        next();
    },
    productUpload.array('images', 8),
    productController.create
);

/**
 * GET /products/user/my-products
 * Produits de l'utilisateur connecté
 */
router.get('/user/my-products', productController.getMyProducts);

/**
 * PATCH /products/:id
 * Modifier un produit
 */
router.patch('/:id', productController.update);

/**
 * DELETE /products/:id
 * Supprimer un produit (soft delete)
 */
router.delete('/:id', productController.delete);

module.exports = router;
