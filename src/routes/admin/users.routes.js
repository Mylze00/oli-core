/**
 * Routes Admin - Gestion Utilisateurs
 * GET /admin/users/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/users
 * Liste tous les utilisateurs avec filtres
 */
router.get('/', async (req, res) => {
    try {
        const { search, role, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT 
                id, phone, name, id_oli, wallet, avatar_url,
                is_admin, is_seller, is_deliverer, is_suspended,
                created_at, last_profile_update
            FROM users
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        // Filtre recherche
        if (search) {
            query += ` AND (phone ILIKE $${paramIndex} OR name ILIKE $${paramIndex} OR id_oli ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        // Filtre rôle
        if (role === 'admin') query += ` AND is_admin = TRUE`;
        if (role === 'seller') query += ` AND is_seller = TRUE`;
        if (role === 'deliverer') query += ` AND is_deliverer = TRUE`;

        query += ` ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/users:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/users/:id
 * Détails d'un utilisateur spécifique
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const userResult = await pool.query(`
            SELECT * FROM users WHERE id = $1
        `, [id]);

        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Utilisateur non trouvé' });
        }

        // Stats produits vendus
        const productsCount = await pool.query(`
            SELECT COUNT(*) as count FROM products WHERE seller_id = $1
        `, [id]);

        res.json({
            user: userResult.rows[0],
            stats: {
                products_count: parseInt(productsCount.rows[0].count)
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/users/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/users/:id/role
 * Modifier les rôles d'un utilisateur
 */
router.patch('/:id/role', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_admin, is_seller, is_deliverer } = req.body;

        const updates = [];
        const values = [];
        let paramIndex = 1;

        if (typeof is_admin === 'boolean') {
            updates.push(`is_admin = $${paramIndex++}`);
            values.push(is_admin);
        }
        if (typeof is_seller === 'boolean') {
            updates.push(`is_seller = $${paramIndex++}`);
            values.push(is_seller);
        }
        if (typeof is_deliverer === 'boolean') {
            updates.push(`is_deliverer = $${paramIndex++}`);
            values.push(is_deliverer);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'Aucune modification fournie' });
        }

        values.push(id);
        const result = await pool.query(`
            UPDATE users 
            SET ${updates.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIndex}
            RETURNING *
        `, values);

        res.json({
            message: 'Rôle mis à jour',
            user: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/users/:id/role:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/users/:id/suspend
 * Suspendre/débloquer un utilisateur
 */
router.post('/:id/suspend', async (req, res) => {
    try {
        const { id } = req.params;
        const { suspended } = req.body;

        await pool.query(`
            UPDATE users 
            SET is_suspended = $1, updated_at = NOW()
            WHERE id = $2
        `, [suspended, id]);

        res.json({
            message: suspended ? 'Utilisateur suspendu' : 'Utilisateur débloqué'
        });
    } catch (err) {
        console.error('Erreur POST /admin/users/:id/suspend:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
