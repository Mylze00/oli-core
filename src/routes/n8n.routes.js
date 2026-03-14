/**
 * Routes n8n - Import automatique de produits depuis captures d'écran chinoises
 * Webhook sécurisé utilisé par le workflow n8n local
 */
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config');
const productService = require('../services/product.service');

// ─── Middleware : Vérification clé secrète n8n ─────────────────────────────
// Sécurité légère : le workflow n8n envoie une clé secrète dans le header
// Plus simple qu'un JWT pour un service interne
const n8nAuth = (req, res, next) => {
    const secretKey = req.headers['x-n8n-secret'];
    const expected = process.env.N8N_WEBHOOK_SECRET || 'oli_n8n_secret_2024';

    if (secretKey !== expected) {
        console.warn('[N8N] Tentative d\'accès non autorisée:', req.ip);
        return res.status(401).json({ error: 'Clé secrète n8n invalide' });
    }
    next();
};

// ─── Middleware : Chargement du compte admin ────────────────────────────────
const loadAdminUser = async (req, res, next) => {
    try {
        const db = require('../config/db');
        const ADMIN_PHONE = process.env.ADMIN_PHONE || '+243827088682';
        const result = await db.query(
            'SELECT id, phone, is_admin, is_seller FROM users WHERE phone = $1 AND is_admin = true LIMIT 1',
            [ADMIN_PHONE]
        );

        if (!result.rows.length) {
            return res.status(500).json({ error: 'Compte admin introuvable' });
        }

        req.user = {
            id: result.rows[0].id,
            phone: result.rows[0].phone,
            is_admin: true,
            is_seller: true
        };

        console.log(`[N8N] Import au nom de l'admin: ${req.user.phone} (ID: ${req.user.id})`);
        next();
    } catch (err) {
        console.error('[N8N] Erreur chargement admin:', err);
        res.status(500).json({ error: 'Erreur serveur lors du chargement admin' });
    }
};

// ─── POST /api/n8n/import-product ──────────────────────────────────────────
/**
 * Import un produit analysé depuis un screenshot chinois.
 *
 * Body JSON attendu :
 * {
 *   "name": "Nom du produit en français",
 *   "description": "Description en français",
 *   "price": 45.99,                          // USD (converti + marge incluse)
 *   "delivery_price": 12.50,                 // Frais de fret calculés
 *   "delivery_time": "10 jours (aérien)",    // Délai livraison
 *   "category": "telephonie",               // Auto-détecté par n8n ou null
 *   "images": ["https://cloudinary.../img1.jpg", "https://..."],  // URLs Cloudinary uploadées par n8n
 *   "condition": "new",
 *   "quantity": 10,
 *   "color": "Bleu",
 *   "location": "Kinshasa",
 *   "source_file": "capture_pindou_1.png",   // Pour logs de traçabilité
 *   "original_price_cny": 199.0,             // Prix source pour référence
 *   "weight_kg": 0.3,                        // Poids extrait par IA
 *   "freight_mode": "air"                    // "air" ou "sea"
 * }
 */
router.post('/import-product', n8nAuth, loadAdminUser, async (req, res) => {
    const {
        name, description, price, delivery_price, delivery_time,
        category, images, condition, quantity, color, location,
        source_file, original_price_cny, weight_kg, freight_mode
    } = req.body;

    // Validation minimale
    if (!name || !price) {
        return res.status(400).json({ error: 'name et price sont requis' });
    }

    if (!images || !Array.isArray(images) || images.length === 0) {
        return res.status(400).json({ error: 'Au moins une image est requise' });
    }

    try {
        console.log(`[N8N] 📦 Import produit: "${name}" | Prix: $${price} | Images: ${images.length} | Source: ${source_file}`);

        // Construire les données produit compatibles avec createProduct
        const productData = {
            name,
            description: description || '',
            price: parseFloat(price),
            delivery_price: parseFloat(delivery_price || 0),
            delivery_time: delivery_time || (freight_mode === 'sea' ? '60 jours (maritime)' : '10 jours (aérien)'),
            category: category || 'other',
            condition: condition || 'new',
            quantity: parseInt(quantity || 1),
            color: color || '',
            location: location || 'Kinshasa',
            is_negotiable: false,
            existing_images: JSON.stringify(images), // URLs déjà uploadées sur Cloudinary
        };

        const productId = await productService.createProduct(req.user.id, productData, []);

        console.log(`[N8N] ✅ Produit créé: ID ${productId} | "${name}" | $${price} | Fret: $${delivery_price} (${freight_mode})`);

        res.status(201).json({
            success: true,
            productId,
            name,
            price,
            delivery_price,
            freight_mode,
            images_count: images.length,
            source_file,
            original_price_cny: original_price_cny || null,
            weight_kg: weight_kg || null,
            message: `Produit "${name}" publié avec succès sur Oli`
        });

    } catch (err) {
        console.error(`[N8N] ❌ Erreur import "${name}":`, err);
        res.status(500).json({
            error: 'Erreur lors de la publication du produit',
            detail: err.message,
            name
        });
    }
});

// ─── GET /api/n8n/status ───────────────────────────────────────────────────
// Health check pour n8n (vérifier que le backend est accessible)
router.get('/status', n8nAuth, (req, res) => {
    res.json({
        status: 'ok',
        service: 'Oli n8n Import Gateway',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

module.exports = router;
