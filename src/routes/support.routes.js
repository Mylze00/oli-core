/**
 * Routes Support utilisateur
 * POST /support/tickets — Créer un ticket
 * GET  /support/tickets — Lister mes tickets
 * GET  /support/tickets/:id — Détails + messages
 * POST /support/tickets/:id/reply — Répondre
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireAuth } = require('../middlewares/auth.middleware');

// Auto-migration des tables support
(async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS support_tickets (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id),
                admin_id INTEGER REFERENCES users(id),
                subject VARCHAR(255) NOT NULL,
                category VARCHAR(50) DEFAULT 'general',
                status VARCHAR(20) DEFAULT 'open',
                priority VARCHAR(20) DEFAULT 'normal',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            )
        `);
        await pool.query(`
            CREATE TABLE IF NOT EXISTS support_messages (
                id SERIAL PRIMARY KEY,
                ticket_id INTEGER NOT NULL REFERENCES support_tickets(id),
                sender_id INTEGER NOT NULL REFERENCES users(id),
                message TEXT NOT NULL,
                is_internal_note BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT NOW()
            )
        `);
        console.log('✅ Tables support_tickets / support_messages OK');
    } catch (e) {
        console.log('⚠️ Tables support déjà existantes ou erreur:', e.message);
    }
})();

// Toutes les routes nécessitent une auth
router.use(requireAuth);

/**
 * POST /support/tickets
 * Créer un nouveau ticket
 */
router.post('/tickets', async (req, res) => {
    try {
        const { subject, message, category } = req.body;
        const userId = req.user.id;

        if (!subject || !message) {
            return res.status(400).json({ error: 'Sujet et message requis' });
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // 1. Créer le ticket
            const ticketRes = await client.query(`
                INSERT INTO support_tickets (user_id, subject, category, status, priority)
                VALUES ($1, $2, $3, 'open', 'normal')
                RETURNING *
            `, [userId, subject.trim(), category || 'general']);

            const ticket = ticketRes.rows[0];

            // 2. Ajouter le premier message
            await client.query(`
                INSERT INTO support_messages (ticket_id, sender_id, message)
                VALUES ($1, $2, $3)
            `, [ticket.id, userId, message.trim()]);

            await client.query('COMMIT');

            res.status(201).json({
                success: true,
                message: 'Ticket créé avec succès',
                ticket
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (err) {
        console.error('Erreur POST /support/tickets:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /support/tickets
 * Lister mes tickets
 */
router.get('/tickets', async (req, res) => {
    try {
        const userId = req.user.id;

        const result = await pool.query(`
            SELECT 
                st.*,
                (SELECT COUNT(*) FROM support_messages sm WHERE sm.ticket_id = st.id) as message_count,
                (SELECT sm.message FROM support_messages sm WHERE sm.ticket_id = st.id ORDER BY sm.created_at DESC LIMIT 1) as last_message
            FROM support_tickets st
            WHERE st.user_id = $1
            ORDER BY st.updated_at DESC
        `, [userId]);

        res.json(result.rows);
    } catch (err) {
        console.error('Erreur GET /support/tickets:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /support/tickets/:id
 * Détails d'un ticket + messages
 */
router.get('/tickets/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const ticketRes = await pool.query(
            'SELECT * FROM support_tickets WHERE id = $1 AND user_id = $2',
            [id, userId]
        );

        if (ticketRes.rows.length === 0) {
            return res.status(404).json({ error: 'Ticket non trouvé' });
        }

        const messagesRes = await pool.query(`
            SELECT sm.*, u.name as sender_name
            FROM support_messages sm
            LEFT JOIN users u ON sm.sender_id = u.id
            WHERE sm.ticket_id = $1 AND sm.is_internal_note = FALSE
            ORDER BY sm.created_at ASC
        `, [id]);

        res.json({
            ticket: ticketRes.rows[0],
            messages: messagesRes.rows
        });
    } catch (err) {
        console.error('Erreur GET /support/tickets/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /support/tickets/:id/reply
 * Répondre à un ticket
 */
router.post('/tickets/:id/reply', async (req, res) => {
    try {
        const { id } = req.params;
        const { message } = req.body;
        const userId = req.user.id;

        if (!message) {
            return res.status(400).json({ error: 'Message requis' });
        }

        // Vérifier que le ticket appartient à l'utilisateur
        const ticket = await pool.query(
            'SELECT id FROM support_tickets WHERE id = $1 AND user_id = $2',
            [id, userId]
        );

        if (ticket.rows.length === 0) {
            return res.status(404).json({ error: 'Ticket non trouvé' });
        }

        await pool.query(`
            INSERT INTO support_messages (ticket_id, sender_id, message)
            VALUES ($1, $2, $3)
        `, [id, userId, message.trim()]);

        // Remettre le ticket en 'open' si l'utilisateur répond
        await pool.query(
            `UPDATE support_tickets SET status = 'open', updated_at = NOW() WHERE id = $1`,
            [id]
        );

        res.json({ success: true, message: 'Réponse envoyée' });
    } catch (err) {
        console.error('Erreur POST /support/tickets/:id/reply:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
