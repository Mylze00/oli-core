const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// --- Configuration Upload (Images Produits) ---
const uploadDir = path.join(__dirname, '../../uploads');
const storage = multer.diskStorage({
    destination: (req, file, cb) => { cb(null, uploadDir); },
    filename: (req, file, cb) => {
        const cleanName = file.originalname.replace(/[^\w.]+/g, '_');
        cb(null, 'prod-' + Date.now() + '-' + cleanName);
    }
});
const upload = multer({ storage: storage });

// --- ROUTES ---

// 1. Lister tous les produits (Marketplace)
router.get('/', async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT p.*, u.name as seller_name, u.avatar_url as seller_avatar FROM products p JOIN users u ON p.seller_id = u.id WHERE p.status = 'active' ORDER BY p.created_at DESC"
        );

        // Formater les URLs d'images et price
        const protocol = req.headers['x-forwarded-proto'] || 'http';
        const host = req.get('host');

        const products = result.rows.map(p => {
            // Gérer le cas où images est une string JSON ou un array PostgreSQL
            let imgs = [];
            if (Array.isArray(p.images)) imgs = p.images;
            else if (typeof p.images === 'string') {
                // Si c'est stocké comme "{url1,url2}" (format PG array string)
                imgs = p.images.replace(/[{}"]/g, '').split(',');
            }

            // Convertir les noms de fichiers en URLs complètes si ce ne sont pas déjà des URLs
            const imageUrls = imgs.map(img =>
                img.startsWith('http') ? img : `${protocol}://${host}/uploads/${img}`
            );

            return {
                id: p.id,
                name: p.name,
                description: p.description,
                price: parseFloat(p.price).toFixed(2),
                category: p.category,
                sellerName: p.seller_name,
                sellerAvatar: p.seller_avatar,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null, // Pour rétrocompatibilité frontend
                images: imageUrls,
                status: p.status
            };
        });

        res.json(products);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// 2. Ajouter un produit (Vente)
router.post('/upload', upload.array('images', 5), async (req, res) => {
    // Note: Le middleware verifyToken doit être appliqué dans server.js
    if (!req.user) return res.status(401).json({ error: "Non authentifié" });

    const { name, description, price, category, delivery_price, delivery_time, condition, quantity, color } = req.body;

    if (!name || !price) return res.status(400).json({ error: "Nom et prix requis" });

    // Récupérer les noms de fichiers
    const images = req.files ? req.files.map(f => f.filename) : [];

    // Si aucune image n'est uploadée, on peut accepter ou refuser. Disons qu'on accepte.

    try {
        const result = await pool.query(
            "INSERT INTO products (seller_id, name, description, price, category, images, delivery_price, delivery_time, condition, quantity, color) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id",
            [
                req.user.id,
                name,
                description || '',
                parseFloat(price),
                category || 'General',
                images,
                parseFloat(delivery_price || 0),
                delivery_time || '',
                condition || 'Neuf',
                parseInt(quantity || 1),
                color || ''
            ]
        );

        res.json({ success: true, productId: result.rows[0].id });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur base de données" });
    }
});

// 3. Mes produits (Profil vendeur)
router.get('/my-products', async (req, res) => {
    if (!req.user) return res.status(401).json({ error: "Non authentifié" });

    try {
        const result = await pool.query(
            "SELECT * FROM products WHERE seller_id = $1 ORDER BY created_at DESC",
            [req.user.id]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: "Erreur serveur" });
    }
});

module.exports = router;
