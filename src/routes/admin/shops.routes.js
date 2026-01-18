/**
 * Routes Admin - Gestion Boutiques (Shops)
 * GET/PATCH /admin/shops/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/shops
 * Liste toutes les boutiques avec statut certification
 */
router.get('/', async (req, res) => {
    try {
        const { search, verified, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT 
                s.*,
                u.name as owner_name,
                u.phone as owner_phone,
                u.avatar_url as owner_avatar,
                COUNT(p.id) as products_count
            FROM shops s
            LEFT JOIN users u ON s.owner_id = u.id
            LEFT JOIN products p ON p.shop_id = s.id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        // Filtre recherche
        if (search) {
            query += ` AND (s.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        // Filtre vérification
        if (verified === 'true') query += ` AND s.is_verified = TRUE`;
        if (verified === 'false') query += ` AND s.is_verified = FALSE`;

        query += ` GROUP BY s.id, u.name, u.phone, u.avatar_url`;
        query += ` ORDER BY s.is_verified DESC, s.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/shops:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/shops/:id
 * Détails d'une boutique
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const shopResult = await pool.query(`
            SELECT 
                s.*,
                u.name as owner_name,
                u.phone as owner_phone,
                u.avatar_url as owner_avatar
            FROM shops s
            LEFT JOIN users u ON s.owner_id = u.id
            WHERE s.id = $1
        `, [id]);

        if (shopResult.rows.length === 0) {
            return res.status(404).json({ error: 'Boutique non trouvée' });
        }

        // Compter les produits
        const productsCount = await pool.query(`
            SELECT COUNT(*) as count FROM products WHERE shop_id = $1
        `, [id]);

        // Top produits
        const topProducts = await pool.query(`
            SELECT id, name, price, images, view_count
            FROM products 
            WHERE shop_id = $1 AND status = 'active'
            ORDER BY view_count DESC
            LIMIT 5
        `, [id]);

        res.json({
            shop: shopResult.rows[0],
            stats: {
                products_count: parseInt(productsCount.rows[0].count)
            },
            top_products: topProducts.rows
        });
    } catch (err) {
        console.error('Erreur GET /admin/shops/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/shops/:id/certify
 * Toggle le statut certifié d'une boutique
 */
router.patch('/:id/certify', async (req, res) => {
    try {
        const { id } = req.params;
        const { certified } = req.body;

        const result = await pool.query(`
            UPDATE shops 
            SET is_verified = $1, updated_at = NOW()
            WHERE id = $2
            RETURNING id, name, is_verified
        `, [certified, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Boutique non trouvée' });
        }

        res.json({
            message: certified ? 'Boutique certifiée' : 'Certification retirée',
            shop: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/shops/:id/certify:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
