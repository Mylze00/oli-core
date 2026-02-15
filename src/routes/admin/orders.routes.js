/**
 * Routes Admin - Gestion Commandes
 * GET /admin/orders/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

router.get('/recent', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT o.id, o.total_amount, o.status, o.created_at, u.name as buyer_name, u.avatar_url
            FROM orders o
            JOIN users u ON o.user_id = u.id
            ORDER BY o.created_at DESC
            LIMIT 5
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/orders/recent:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/orders
 * Liste toutes les commandes
 */
router.get('/', async (req, res) => {
    try {
        const { status, limit = 50, offset = 0 } = req.query;

        // Vérifier si table orders existe
        const tableExists = await pool.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'orders'
            )
        `);

        if (!tableExists.rows[0].exists) {
            return res.json({
                message: 'Table orders pas encore créée',
                orders: []
            });
        }

        let query = `
            SELECT o.*,
                   u.name as buyer_name,
                   u.phone as buyer_phone,
                   (
                       SELECT json_agg(json_build_object(
                           'product_id', oi.product_id,
                           'quantity', oi.quantity,
                           'price', oi.product_price,
                           'product_name', COALESCE(p.name, oi.product_name)
                       ))
                       FROM order_items oi
                       LEFT JOIN products p ON oi.product_id::integer = p.id
                       WHERE oi.order_id = o.id
                   ) as items
            FROM orders o
            JOIN users u ON o.user_id = u.id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (status) {
            query += ` AND o.status = $${paramIndex++}`;
            params.push(status);
        }

        query += ` ORDER BY o.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/orders:', err);
        res.status(500).json({ error: 'Erreur serveur', details: err.message });
    }
});

/**
 * GET /admin/orders/:id
 * Détails commande
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT o.*,
                   u.name as buyer_name,
                   u.phone as buyer_phone
            FROM orders o
            JOIN users u ON o.user_id = u.id
            WHERE o.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Commande non trouvée' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erreur GET /admin/orders/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/orders/:id/status
 * Modifier statut commande manuellement
 */
router.patch('/:id/status', async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body;

        const validStatuses = ['pending', 'paid', 'processing', 'ready', 'confirmed', 'shipped', 'delivered', 'cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: 'Statut invalide' });
        }

        await pool.query(`
            UPDATE orders 
            SET status = $1, updated_at = NOW()
            WHERE id = $2
        `, [status, id]);

        // 💰 Si statut passe à 'delivered', créditer le(s) vendeur(s)
        if (status === 'delivered') {
            try {
                const walletService = require('../../services/wallet.service');
                const itemsResult = await pool.query(
                    `SELECT p.seller_id, SUM(oi.product_price * oi.quantity) as seller_total
                     FROM order_items oi
                     JOIN products p ON oi.product_id::integer = p.id
                     WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL
                     GROUP BY p.seller_id`,
                    [id]
                );
                for (const row of itemsResult.rows) {
                    const amount = parseFloat(row.seller_total);
                    if (amount > 0) {
                        await walletService.creditSeller(row.seller_id, amount, id);
                    }
                }
            } catch (creditErr) {
                console.error('⚠️ Erreur crédit vendeur (admin):', creditErr.message);
            }
        }

        res.json({ message: 'Statut mis à jour' });
    } catch (err) {
        console.error('Erreur PATCH /admin/orders/:id/status:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
