/**
 * Routes Admin - Support Tickets
 * GET/POST/PATCH /admin/support/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/support
 * Liste les tickets avec filtres
 */
router.get('/', async (req, res) => {
    try {
        const { status, priority, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT 
                st.*,
                u.name as user_name,
                u.phone as user_phone,
                u.avatar_url as user_avatar,
                adm.name as admin_name
            FROM support_tickets st
            JOIN users u ON st.user_id = u.id
            LEFT JOIN users adm ON st.admin_id = adm.id
            WHERE 1=1
        `;

        const params = [];
        let paramIndex = 1;

        if (status) {
            query += ` AND st.status = $${paramIndex++}`;
            params.push(status);
        }

        if (priority) {
            query += ` AND st.priority = $${paramIndex++}`;
            params.push(priority);
        }

        query += ` ORDER BY st.updated_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /admin/support:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/support/stats
 * Stats rapides
 */
router.get('/stats', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                COUNT(*) FILTER (WHERE status = 'open') as open_count,
                COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
                COUNT(*) FILTER (WHERE status = 'resolved') as resolved_count,
                COUNT(*) FILTER (WHERE priority = 'urgent' AND status != 'resolved') as urgent_count
            FROM support_tickets
        `);
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erreur GET /admin/support/stats:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/support/:id
 * Détails d'un ticket + messages
 */
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;

        const ticketQuery = `
            SELECT 
                st.*,
                u.name as user_name,
                u.phone as user_phone,
                u.avatar_url as user_avatar,
                (SELECT COUNT(*) FROM orders o WHERE o.user_id = st.user_id) as user_orders_count
            FROM support_tickets st
            JOIN users u ON st.user_id = u.id
            WHERE st.id = $1
        `;

        const messagesQuery = `
            SELECT 
                sm.*,
                u.name as sender_name,
                u.avatar_url as sender_avatar
            FROM support_messages sm
            LEFT JOIN users u ON sm.sender_id = u.id
            WHERE sm.ticket_id = $1
            ORDER BY sm.created_at ASC
        `;

        const [ticketRes, messagesRes] = await Promise.all([
            pool.query(ticketQuery, [id]),
            pool.query(messagesQuery, [id])
        ]);

        if (ticketRes.rows.length === 0) {
            return res.status(404).json({ error: 'Ticket non trouvé' });
        }

        res.json({
            ticket: ticketRes.rows[0],
            messages: messagesRes.rows
        });
    } catch (err) {
        console.error('Erreur GET /admin/support/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /admin/support/:id/reply
 * Répondre à un ticket
 */
router.post('/:id/reply', async (req, res) => {
    const client = await pool.connect();
    try {
        const { id } = req.params;
        const { message, status } = req.body;
        const adminId = req.user.id; // Supposant middleware auth

        await client.query('BEGIN');

        // 1. Ajouter le message
        await client.query(`
            INSERT INTO support_messages (ticket_id, sender_id, message, is_internal_note)
            VALUES ($1, $2, $3, false)
        `, [id, adminId, message]);

        // 2. Mettre à jour le ticket (status + updated_at + admin_id si pas encore assigné)
        let updateQuery = `
            UPDATE support_tickets 
            SET updated_at = NOW(),
                admin_id = COALESCE(admin_id, $1)
        `;
        const params = [adminId];
        let paramIdx = 2;

        if (status) {
            updateQuery += `, status = $${paramIdx++}`;
            params.push(status);
        } else {
            // Si pas de statut forcé, passer en 'pending' (attente réponse user)
            updateQuery += `, status = 'pending'`;
        }

        updateQuery += ` WHERE id = $${paramIdx}`;
        params.push(id);

        await client.query(updateQuery, params);

        await client.query('COMMIT');
        res.json({ message: 'Réponse envoyée' });

    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Erreur POST /admin/support/:id/reply:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    } finally {
        client.release();
    }
});

/**
 * PATCH /admin/support/:id
 * Modifier statut/priorité/assignation
 */
router.patch('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { status, priority, admin_id } = req.body;

        const fields = [];
        const params = [];
        let paramIdx = 1;

        if (status) {
            fields.push(`status = $${paramIdx++}`);
            params.push(status);
        }
        if (priority) {
            fields.push(`priority = $${paramIdx++}`);
            params.push(priority);
        }
        if (admin_id) {
            fields.push(`admin_id = $${paramIdx++}`);
            params.push(admin_id);
        }

        if (fields.length === 0) return res.status(400).json({ error: 'Aucun champ à modifier' });

        params.push(id);
        const query = `
            UPDATE support_tickets 
            SET ${fields.join(', ')}, updated_at = NOW()
            WHERE id = $${paramIdx}
            RETURNING *
        `;

        const result = await pool.query(query, params);
        res.json(result.rows[0]);

    } catch (err) {
        console.error('Erreur PATCH /admin/support/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
