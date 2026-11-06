/**
 * Routes publiques Billetterie O-Ticket
 *
 * Montées sous /tickets.
 *  GET  /events        — événements publiés (catalogue)
 *  GET  /events/:id    — détail d'un événement + catégories disponibles
 *  POST /purchase      — acheter des billets (débit wallet, atomique) [auth]
 *  GET  /my            — mes billets [auth]
 */
const express = require('express');
const crypto = require('crypto');
const pool = require('../config/db');
const walletRepository = require('../repositories/wallet.repository');
const { requireAuth } = require('../middlewares/auth.middleware');

const router = express.Router();

// ─── Catalogue : événements publiés et à venir ───────────────────────────────
router.get('/events', async (req, res) => {
    try {
        const { category } = req.query;
        const params = [];
        let catFilter = '';
        if (category) { params.push(category); catFilter = `AND e.category = $${params.length}`; }

        const { rows } = await pool.query(`
            SELECT e.id, e.title, e.subtitle, e.category, e.event_date, e.event_time,
                   e.location, e.image_url,
                   COALESCE(MIN(tt.price_fc), 0)                         AS min_price_fc,
                   COALESCE(SUM(tt.quantity_total - tt.quantity_sold), 0)::int AS remaining
              FROM events e
              LEFT JOIN event_ticket_types tt ON tt.event_id = e.id
             WHERE e.status = 'published' ${catFilter}
             GROUP BY e.id
             ORDER BY e.event_date ASC
             LIMIT 100
        `, params);
        res.json(rows);
    } catch (err) {
        console.error('❌ [O-Ticket] catalogue:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Détail d'un événement ───────────────────────────────────────────────────
router.get('/events/:id', async (req, res) => {
    try {
        const ev = await pool.query(
            `SELECT * FROM events WHERE id = $1 AND status = 'published'`,
            [req.params.id]
        );
        if (!ev.rows.length) return res.status(404).json({ error: 'Événement introuvable' });

        const types = await pool.query(`
            SELECT id, name, price_fc, quantity_total, quantity_sold,
                   (quantity_total - quantity_sold) AS remaining
              FROM event_ticket_types WHERE event_id = $1 ORDER BY price_fc DESC
        `, [req.params.id]);

        res.json({ ...ev.rows[0], ticket_types: types.rows });
    } catch (err) {
        console.error('❌ [O-Ticket] détail événement:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Achat de billets : stock, débit wallet et émission dans une transaction ─
router.post('/purchase', requireAuth, async (req, res) => {
    const { ticket_type_id, quantity } = req.body || {};
    const qty = parseInt(quantity, 10) || 1;
    if (!ticket_type_id) return res.status(400).json({ error: 'Catégorie de billet requise' });
    if (qty < 1 || qty > 10) return res.status(400).json({ error: 'Quantité entre 1 et 10' });

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Catégorie + événement, sous verrou (évite la survente)
        const typeRes = await client.query(`
            SELECT tt.*, e.title AS event_title, e.status AS event_status
              FROM event_ticket_types tt
              JOIN events e ON e.id = tt.event_id
             WHERE tt.id = $1 FOR UPDATE OF tt
        `, [ticket_type_id]);
        if (!typeRes.rows.length) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Catégorie de billet introuvable' });
        }
        const type = typeRes.rows[0];
        if (type.event_status !== 'published') {
            await client.query('ROLLBACK');
            return res.status(409).json({ error: "Cet événement n'est pas en vente" });
        }
        const remaining = type.quantity_total - type.quantity_sold;
        if (type.quantity_total > 0 && qty > remaining) {
            await client.query('ROLLBACK');
            return res.status(409).json({ error: `Plus que ${remaining} billet(s) disponible(s)` });
        }

        // 2. Débit du wallet, sous verrou
        const total = parseFloat(type.price_fc) * qty;
        const wallet = await walletRepository._getOrCreateWallet(req.user.id, client);
        if (wallet.is_frozen) {
            await client.query('ROLLBACK');
            return res.status(403).json({ error: 'Votre wallet est gelé' });
        }
        const before = parseFloat(wallet.balance);
        if (before < total) {
            await client.query('ROLLBACK');
            return res.status(402).json({
                error: `Solde insuffisant : ${total.toFixed(0)} FC requis, ${before.toFixed(0)} FC disponibles`,
            });
        }
        const after = before - total;
        const reference = `TICKET_${type.event_id}_${req.user.id}_${Date.now()}`;

        await client.query('UPDATE wallets SET balance = $1 WHERE id = $2', [after, wallet.id]);
        await client.query('UPDATE users SET wallet = $1 WHERE id = $2', [after, req.user.id]);
        await walletRepository._insertTx(client, {
            userId: req.user.id,
            type: 'payment',
            amount: -total,
            balanceBefore: before,
            balanceAfter: after,
            provider: 'O_TICKET',
            reference,
            description: `${qty} billet(s) — ${type.event_title} (${type.name})`,
        });

        // 3. Émission des billets
        const tickets = [];
        for (let i = 0; i < qty; i++) {
            const code = 'TKT-OLI-' + crypto.randomBytes(5).toString('hex').toUpperCase();
            const { rows } = await client.query(`
                INSERT INTO event_tickets (ticket_code, event_id, ticket_type_id, buyer_id, seat_label, price_paid_fc)
                VALUES ($1,$2,$3,$4,$5,$6) RETURNING *
            `, [code, type.event_id, type.id, req.user.id, type.name, type.price_fc]);
            tickets.push(rows[0]);
        }
        await client.query(
            'UPDATE event_ticket_types SET quantity_sold = quantity_sold + $2 WHERE id = $1',
            [type.id, qty]
        );

        await client.query('COMMIT');
        res.status(201).json({ success: true, tickets, totalPaidFC: total, newBalanceFC: after });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ [O-Ticket] achat:', err.message);
        res.status(500).json({ error: "Achat impossible pour le moment" });
    } finally {
        client.release();
    }
});

// ─── Mes billets ─────────────────────────────────────────────────────────────
router.get('/my', requireAuth, async (req, res) => {
    try {
        const { rows } = await pool.query(`
            SELECT t.id, t.ticket_code, t.seat_label, t.price_paid_fc, t.status, t.created_at,
                   e.id AS event_id, e.title, e.subtitle, e.category,
                   e.event_date, e.event_time, e.location, e.image_url,
                   tt.name AS type_name
              FROM event_tickets t
              JOIN events e ON e.id = t.event_id
              LEFT JOIN event_ticket_types tt ON tt.id = t.ticket_type_id
             WHERE t.buyer_id = $1
             ORDER BY (t.status = 'valid') DESC, e.event_date DESC
             LIMIT 100
        `, [req.user.id]);
        res.json(rows);
    } catch (err) {
        console.error('❌ [O-Ticket] mes billets:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
