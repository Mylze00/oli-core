const productService = require('../services/product.service');

exports.getFeatured = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;
        const products = await productService.getFeaturedProducts(limit);
        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/featured:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getTopSellers = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const products = await productService.getTopSellers(limit);
        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/top-sellers:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getVerifiedShops = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const products = await productService.getVerifiedShopsProducts(limit);
        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/verified-shops:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getAll = async (req, res) => {
    try {
        const filters = {
            category: req.query.category,
            minPrice: req.query.minPrice,
            maxPrice: req.query.maxPrice,
            location: req.query.location,
            search: req.query.search,
            shopId: req.query.shopId
        };
        // Limite raisonnable : 200 produits par page pour éviter surcharge data/performance
        const limit = parseInt(req.query.limit) || 200;
        const offset = parseInt(req.query.offset) || 0;

        const products = await productService.getAllProducts(filters, limit, offset);
        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.getById = async (req, res) => {
    try {
        const { id } = req.params;
        const product = await productService.getProductById(id);

        if (!product) {
            return res.status(404).json({ error: "Produit non trouvé" });
        }

        res.json(product);
    } catch (err) {
        console.error("Erreur GET /products/:id:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.create = async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        console.log(`📡 [UPLOAD] Requête reçue de ${req.user.id}. Fichiers : ${req.files?.length || 0}`);

        const productId = await productService.createProduct(req.user.id, req.body, req.files);

        console.log(`✅ Produit créé avec succès : ID ${productId} par User ${req.user.id}`);

        res.status(201).json({
            success: true,
            productId: productId,
            message: "Produit publié avec succès"
        });
    } catch (err) {
        console.error("❌ ERREUR CRITIQUE POST /products/upload:", err);
        res.status(500).json({
            error: "Erreur lors de la publication",
            detail: err.message
        });
    }
};

exports.getMyProducts = async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        const products = await productService.getUserProducts(req.user.id);
        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/user/my-products:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.update = async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        const { id } = req.params;
        const result = await productService.updateProduct(req.user.id, id, req.body);

        res.json({ success: true, product: result });
    } catch (err) {
        console.error("Erreur PATCH /products/:id:", err);
        if (err.message === 'Non autorisé') {
            return res.status(403).json({ error: "Non autorisé" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};

exports.delete = async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        const { id } = req.params;
        await productService.deleteProduct(req.user.id, id);
        res.json({ success: true, message: "Produit supprimé" });
    } catch (err) {
        console.error("Erreur DELETE /products/:id:", err);
        if (err.message === 'Non autorisé ou produit inexistant') {
            return res.status(403).json({ error: "Non autorisé ou produit inexistant" });
        }
        res.status(500).json({ error: "Erreur serveur" });
    }
};
