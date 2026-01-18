/**
 * Routes Admin - Gestion Produits
 * GET /admin/products/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/products
 * Liste tous les produits (admin view - inclut supprimés)
 */
router.get('/', async (req, res) => {
    try {
        const { status, is_featured, search, limit = 100, offset = 0 } = req.query;

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

        // Recherche par nom produit ou téléphone vendeur
        if (search) {
            query += ` AND (p.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex} OR u.name ILIKE $${paramIndex})`;
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
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/products:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/feature
 * Toggle produit featured
 */
router.patch('/:id/feature', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_featured } = req.body;

        const result = await pool.query(`
            UPDATE products 
            SET is_featured = $1, updated_at = NOW()
            WHERE id = $2
            RETURNING *
        `, [is_featured, id]);

        res.json({
            message: is_featured ? 'Produit mis en avant' : 'Produit retiré des featured',
            product: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/feature:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /admin/products/:id
 * Supprimer définitivement un produit (ou bannir)
 */
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        // Soft delete (status = banned)
        await pool.query(`
            UPDATE products 
            SET status = 'banned', updated_at = NOW()
            WHERE id = $1
        `, [id]);

        res.json({ message: 'Produit banni' });
    } catch (err) {
        console.error('Erreur DELETE /admin/products/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/reported
 * Produits signalés (futur: table reports)
 */
router.get('/reported', async (req, res) => {
    try {
        // TODO: implémenter table product_reports
        res.json([]);
    } catch (err) {
        console.error('Erreur GET /admin/products/reported:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
