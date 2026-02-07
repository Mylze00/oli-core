/**
 * Routes Admin - Gestion Produits
 * GET /admin/products/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');
const { BASE_URL } = require('../../config');

/**
 * GET /admin/products
 * Liste tous les produits avec stats globales
 */
router.get('/', async (req, res) => {
    try {
        const { status, is_featured, search, limit = 100, offset = 0 } = req.query;

        // ── Stats globales ──
        let globalStats = { total: 0, active: 0, banned: 0, featured: 0, good_deals: 0 };
        try {
            const statsResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE status = 'active') as active,
                    COUNT(*) FILTER (WHERE status = 'banned') as banned,
                    COUNT(*) FILTER (WHERE is_featured = TRUE) as featured,
                    COUNT(*) FILTER (WHERE is_good_deal = TRUE) as good_deals
                FROM products
            `);
            globalStats = statsResult.rows[0];
        } catch (e) { console.warn('products stats error:', e.message); }

        // ── Requête principale ──
        let query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.phone as seller_phone,
                   u.avatar_url as seller_avatar,
                   u.is_admin as seller_is_admin
            FROM products p
            JOIN users u ON p.seller_id = u.id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (search) {
            query += ` AND (p.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex} OR u.name ILIKE $${paramIndex} OR p.category ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        if (status) {
            query += ` AND p.status = $${paramIndex++}`;
            params.push(status);
        }

        if (is_featured !== undefined) {
            query += ` AND p.is_featured = $${paramIndex++}`;
            params.push(is_featured === 'true');
        }

        query += ` ORDER BY p.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);

        // Formater les images
        const products = result.rows.map(p => {
            let image_url = null;
            if (p.images && p.images.length > 0) {
                const first = p.images[0];
                image_url = first.startsWith('http') ? first : `${BASE_URL}/uploads/${first}`;
            }
            return { ...p, image_url };
        });

        res.json({
            products,
            stats: {
                total: parseInt(globalStats.total),
                active: parseInt(globalStats.active),
                banned: parseInt(globalStats.banned),
                featured: parseInt(globalStats.featured),
                good_deals: parseInt(globalStats.good_deals),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/products:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/feature
 */
router.patch('/:id/feature', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_featured } = req.body;
        const result = await pool.query(`UPDATE products SET is_featured = $1, updated_at = NOW() WHERE id = $2 RETURNING *`, [is_featured, id]);
        res.json({ message: is_featured ? 'Produit mis en avant' : 'Produit retiré des featured', product: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/feature:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /admin/products/:id
 */
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query(`UPDATE products SET status = 'banned', updated_at = NOW() WHERE id = $1`, [id]);
        res.json({ message: 'Produit banni' });
    } catch (err) {
        console.error('Erreur DELETE /admin/products/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/good-deals
 */
router.get('/good-deals', async (req, res) => {
    try {
        const products = await require('../../repositories/product.repository').findGoodDeals(20);
        res.json(products);
    } catch (err) {
        console.error('Erreur GET /admin/products/good-deals:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/good-deal
 */
router.patch('/:id/good-deal', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_good_deal, promo_price } = req.body;
        const updates = { is_good_deal };
        if (promo_price !== undefined) updates.promo_price = promo_price;
        const product = await require('../../repositories/product.repository').update(id, updates);
        if (!product) return res.status(404).json({ error: 'Produit introuvable' });
        res.json({ message: 'Bon Deal mis à jour', product });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/good-deal:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/reported
 */
router.get('/reported', async (req, res) => {
    try { res.json([]); }
    catch (err) { console.error('Erreur GET /admin/products/reported:', err); res.status(500).json({ error: 'Erreur serveur' }); }
});

module.exports = router;
