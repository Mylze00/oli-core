/**
 * Routes Produits Oli
 * Marketplace - Catalogue, Upload, Gestion
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { BASE_URL } = require('../config');
const { productUpload } = require('../config/upload');

/**
 * GET /products/featured
 * Produits mis en avant par l'admin (pour page Accueil)
 */
router.get('/featured', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 20;

        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.is_featured = TRUE 
              AND p.status = 'active'
            ORDER BY p.created_at DESC
            LIMIT $1
        `;

        const result = await pool.query(query, [limit]);

        // Formater les URLs d'images (même logique que GET /)
        const products = result.rows.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}"]/g, '').split(',').filter(Boolean);
            }

            const imageUrls = imgs.map(img => {
                if (!img) return null;
                if (img.startsWith('http')) return img;
                return `${BASE_URL}/uploads/${img}`;
            }).filter(url => url !== null);

            return {
                id: p.id,
                name: p.name,
                description: p.description,
                price: parseFloat(p.price).toFixed(2),
                category: p.category,
                condition: p.condition,
                quantity: p.quantity,
                color: p.color,
                location: p.location,
                isNegotiable: p.is_negotiable,
                deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
                deliveryTime: p.delivery_time,
                sellerId: p.seller_id,
                sellerName: p.seller_name,
                sellerAvatar: p.seller_avatar,
                sellerOliId: p.seller_oli_id,
                shopId: p.shop_id,
                shopName: p.shop_name,
                shopVerified: p.shop_verified,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
                images: imageUrls,
                status: p.status,
                createdAt: p.created_at,
                isFeatured: true // Indicateur
            };
        });

        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/featured:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /products/top-sellers
 * Meilleurs vendeurs du marketplace (produits les plus vendus/consultés)
 */
router.get('/top-sellers', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;

        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
            ORDER BY COALESCE(p.view_count, 0) DESC, p.created_at DESC
            LIMIT $1
        `;

        const result = await pool.query(query, [limit]);

        const products = result.rows.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}"]/g, '').split(',').filter(Boolean);
            }

            const imageUrls = imgs.map(img => {
                if (!img) return null;
                if (img.startsWith('http')) return img;
                return `${BASE_URL}/uploads/${img}`;
            }).filter(url => url !== null);

            return {
                id: p.id,
                name: p.name,
                description: p.description,
                price: parseFloat(p.price).toFixed(2),
                category: p.category,
                condition: p.condition,
                quantity: p.quantity,
                color: p.color,
                location: p.location,
                isNegotiable: p.is_negotiable,
                deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
                deliveryTime: p.delivery_time,
                sellerId: p.seller_id,
                sellerName: p.seller_name,
                sellerAvatar: p.seller_avatar,
                sellerOliId: p.seller_oli_id,
                shopId: p.shop_id,
                shopName: p.shop_name,
                shopVerified: p.shop_verified,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
                images: imageUrls,
                status: p.status,
                createdAt: p.created_at,
                viewCount: p.view_count || 0
            };
        });

        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/top-sellers:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /products/verified-shops
 * Produits des grands magasins vérifiés (shops is_verified = true)
 */
router.get('/verified-shops', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;

        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   s.name as shop_name, 
                   s.is_verified as shop_verified,
                   s.logo_url as shop_logo
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
              AND s.is_verified = TRUE
            ORDER BY p.created_at DESC
            LIMIT $1
        `;

        const result = await pool.query(query, [limit]);

        const products = result.rows.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}"]/g, '').split(',').filter(Boolean);
            }

            const imageUrls = imgs.map(img => {
                if (!img) return null;
                if (img.startsWith('http')) return img;
                return `${BASE_URL}/uploads/${img}`;
            }).filter(url => url !== null);

            return {
                id: p.id,
                name: p.name,
                description: p.description,
                price: parseFloat(p.price).toFixed(2),
                category: p.category,
                condition: p.condition,
                quantity: p.quantity,
                color: p.color,
                location: p.location,
                isNegotiable: p.is_negotiable,
                deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
                deliveryTime: p.delivery_time,
                sellerId: p.seller_id,
                sellerName: p.seller_name,
                sellerAvatar: p.seller_avatar,
                sellerOliId: p.seller_oli_id,
                shopId: p.shop_id,
                shopName: p.shop_name,
                shopVerified: true,
                shopLogo: p.shop_logo,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
                images: imageUrls,
                status: p.status,
                createdAt: p.created_at
            };
        });

        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products/verified-shops:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /products
 * Liste tous les produits actifs (public)
 */
router.get('/', async (req, res) => {
    try {
        const { category, minPrice, maxPrice, location, search, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
        `;

        const params = [];
        let paramIndex = 1;

        // Filtres dynamiques
        if (category) {
            query += ` AND p.category = $${paramIndex++}`;
            params.push(category);
        }
        if (minPrice) {
            query += ` AND p.price >= $${paramIndex++}`;
            params.push(parseFloat(minPrice));
        }
        if (maxPrice) {
            query += ` AND p.price <= $${paramIndex++}`;
            params.push(parseFloat(maxPrice));
        }
        if (location) {
            query += ` AND p.location ILIKE $${paramIndex++}`;
            params.push(`%${location}%`);
        }
        if (search) {
            query += ` AND (p.name ILIKE $${paramIndex} OR p.description ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        query += ` ORDER BY p.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);

        // Formater les URLs d'images
        const products = result.rows.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}\"]/g, '').split(',').filter(Boolean);
            }

            const imageUrls = imgs.map(img => {
                if (!img) return null;
                if (img.startsWith('http')) return img;
                return `${BASE_URL}/uploads/${img}`;
            }).filter(url => url !== null);

            return {
                id: p.id,
                name: p.name,
                description: p.description,
                price: parseFloat(p.price).toFixed(2),
                category: p.category,
                condition: p.condition,
                quantity: p.quantity,
                color: p.color,
                location: p.location,
                isNegotiable: p.is_negotiable,
                deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
                deliveryTime: p.delivery_time,
                sellerId: p.seller_id,
                sellerName: p.seller_name,
                sellerAvatar: p.seller_avatar,
                sellerOliId: p.seller_oli_id,
                shopId: p.shop_id,
                shopName: p.shop_name,
                shopVerified: p.shop_verified,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
                images: imageUrls,
                status: p.status,
                createdAt: p.created_at,
            };
        });

        res.json(products);
    } catch (err) {
        console.error("Erreur GET /products:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * GET /products/:id
 * Détails d'un produit
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.phone as seller_phone,
                   u.rating as seller_rating,
                   s.name as shop_name
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Produit non trouvé" });
        }

        const p = result.rows[0];

        // Incrémenter les vues
        await pool.query("UPDATE products SET view_count = COALESCE(view_count, 0) + 1 WHERE id = $1", [id]);

        // Formater
        let imgs = Array.isArray(p.images) ? p.images :
            (typeof p.images === 'string' ? p.images.replace(/[{}\"]/g, '').split(',').filter(Boolean) : []);

        res.json({
            ...p,
            images: imgs.map(img => img.startsWith('http') ? img : `${BASE_URL}/uploads/${img}`),
            price: parseFloat(p.price).toFixed(2),
            deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
        });
    } catch (err) {
        console.error("Erreur GET /products/:id:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * POST /products/upload
 * Créer un nouveau produit (auth requise via middleware)
 */
router.post('/upload', (req, res, next) => {
    console.log("🛠️ Tentative d'upload - Passage vers Multer...");
    next();
}, productUpload.array('images', 8), async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    const {
        name, description, price, category,
        delivery_price, delivery_time, condition,
        quantity, color, location, shop_id, is_negotiable
    } = req.body;

    if (!name || !price) {
        return res.status(400).json({ error: "Nom et prix requis" });
    }

    console.log(`📡 [UPLOAD] Requête reçue de ${req.user?.id}. Fichiers : ${req.files?.length || 0}`);
    const images = req.files ? req.files.map(f => {
        console.log(`  - Fichier: ${f.originalname} -> ${f.path || f.filename}`);
        return f.path || f.filename;
    }) : [];

    try {
        const result = await pool.query(`
            INSERT INTO products (
                seller_id, shop_id, name, description, price, category, 
                images, delivery_price, delivery_time, condition, 
                quantity, color, location, is_negotiable, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'active') 
            RETURNING id
        `, [
            req.user.id,
            (shop_id && shop_id !== "" && shop_id !== "null") ? parseInt(shop_id) : null,
            name,
            description || '',
            parseFloat(price) || 0,
            category || 'Général',
            images,
            parseFloat(delivery_price || 0),
            delivery_time || '',
            condition || 'Neuf',
            parseInt(quantity || 1),
            color || '',
            location || '',
            is_negotiable === 'true' || is_negotiable === true
        ]);

        console.log(`✅ Produit créé avec succès : ID ${result.rows[0].id} par User ${req.user.id}`);

        // Mettre à jour le compteur de ventes de l'utilisateur
        await pool.query("UPDATE users SET total_sales = COALESCE(total_sales, 0) + 1 WHERE id = $1", [req.user.id]);

        res.status(201).json({
            success: true,
            productId: result.rows[0].id,
            message: "Produit publié avec succès"
        });
    } catch (err) {
        console.error("❌ ERREUR CRITIQUE POST /products/upload:");
        console.error("- Message:", err.message);
        console.error("- Stack:", err.stack);
        console.error("- Payload:", { name, price, category, shop_id, userId: req.user?.id });

        // Retourner une erreur plus descriptive au client si possible
        res.status(500).json({
            error: "Erreur lors de la publication",
            detail: err.message,
            code: err.code
        });
    }
});

/**
 * GET /products/my-products
 * Produits de l'utilisateur connecté
 */
router.get('/user/my-products', async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    try {
        const result = await pool.query(
            "SELECT * FROM products WHERE seller_id = $1 ORDER BY created_at DESC",
            [req.user.id]
        );

        const products = result.rows.map(p => ({
            ...p,
            images: Array.isArray(p.images) ? p.images.map(img =>
                img.startsWith('http') ? img : `${BASE_URL}/uploads/${img}`
            ) : []
        }));

        res.json(products);
    } catch (err) {
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * PATCH /products/:id
 * Modifier un produit
 */
router.patch('/:id', async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    const { id } = req.params;
    const updates = req.body;

    try {
        // Vérifier que le produit appartient à l'utilisateur
        const check = await pool.query(
            "SELECT id FROM products WHERE id = $1 AND seller_id = $2",
            [id, req.user.id]
        );

        if (check.rows.length === 0) {
            return res.status(403).json({ error: "Non autorisé" });
        }

        // Construire la requête dynamiquement
        const fields = ['name', 'description', 'price', 'category', 'condition',
            'quantity', 'color', 'location', 'status', 'delivery_price', 'delivery_time'];
        const setClauses = [];
        const values = [];
        let i = 1;

        for (const field of fields) {
            if (updates[field] !== undefined) {
                setClauses.push(`${field} = $${i++}`);
                values.push(updates[field]);
            }
        }

        if (setClauses.length === 0) {
            return res.status(400).json({ error: "Aucune modification fournie" });
        }

        setClauses.push(`updated_at = NOW()`);
        values.push(id);

        const result = await pool.query(
            `UPDATE products SET ${setClauses.join(', ')} WHERE id = $${i} RETURNING *`,
            values
        );

        res.json({ success: true, product: result.rows[0] });
    } catch (err) {
        console.error("Erreur PATCH /products/:id:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * DELETE /products/:id
 * Supprimer un produit (soft delete)
 */
router.delete('/:id', async (req, res) => {
    if (!req.user) {
        return res.status(401).json({ error: "Non authentifié" });
    }

    const { id } = req.params;

    try {
        const result = await pool.query(
            "UPDATE products SET status = 'deleted', updated_at = NOW() WHERE id = $1 AND seller_id = $2 RETURNING id",
            [id, req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(403).json({ error: "Non autorisé ou produit inexistant" });
        }

        res.json({ success: true, message: "Produit supprimé" });
    } catch (err) {
        res.status(500).json({ error: "Erreur serveur" });
    }
});

module.exports = router;
