/**
 * Routes Admin — Billetterie O-Ticket
 *
 * Montées sous /admin/ticketing (requireAuth + requireAdmin appliqués en amont
 * par admin.routes.js).
 *
 *  Événements      : GET / POST / PUT / PATCH status / DELETE  /events
 *  Catégories      : GET / POST  /events/:id/types,  DELETE /types/:id
 *  Billets (ventes): GET /sales,  PATCH /tickets/:id/status
 *  Statistiques    : GET /stats
 */
const express = require('express');
const crypto = require('crypto');
const pool = require('../../config/db');
const walletRepository = require('../../repositories/wallet.repository');
const userRepository = require('../../repositories/user.repository');
const { genericUpload } = require('../../config/upload');

const router = express.Router();

const EVENT_STATUSES = ['draft', 'published', 'cancelled', 'finished'];
const CATEGORIES = ['concert', 'cinema', 'sport', 'conference', 'festival', 'autre'];
const TICKET_STATUSES = ['valid', 'used', 'cancelled', 'refunded'];

/** Normalise un numéro en format international (RDC par défaut). */
function normalizePhone(raw) {
    if (typeof raw !== 'string') return null;
    let s = raw.replace(/[\s\-().]/g, '');
    if (s.startsWith('00')) s = '+' + s.slice(2);
    if (s.startsWith('0') && !s.startsWith('+')) s = '+243' + s.slice(1);
    return /^\+[1-9]\d{7,14}$/.test(s) ? s : null;
}

/**
 * Enregistre les organisateurs d'un événement à partir de leurs numéros.
 * Un numéro sans compte Oli en crée un : l'organisateur se connectera
 * ensuite avec ce numéro pour scanner les billets.
 * Renvoie { saved: [...], invalid: [...] }.
 */
async function setOrganizers(eventId, phones) {
    const saved = [];
    const invalid = [];
    const list = Array.isArray(phones) ? phones : [];

    for (const raw of list) {
        const phone = normalizePhone(String(raw || ''));
        if (!phone) { if (String(raw || '').trim()) invalid.push(String(raw)); continue; }
        let user = await userRepository.findByPhone(phone);
        if (!user) user = await userRepository.createUser(phone);
        await pool.query(
            `INSERT INTO event_organizers (event_id, user_id, phone)
             VALUES ($1,$2,$3) ON CONFLICT (event_id, user_id) DO NOTHING`,
            [eventId, user.id, phone]
        );
        saved.push({ id: user.id, phone, name: user.name || null });
    }

    // Le premier organisateur reste la référence dans events.organizer_id
    if (saved.length) {
        await pool.query('UPDATE events SET organizer_id = $2 WHERE id = $1', [eventId, saved[0].id]);
    }
    return { saved, invalid };
}

// ─── Statistiques globales ───────────────────────────────────────────────────
router.get('/stats', async (req, res) => {
    try {
        const { rows } = await pool.query(`
            SELECT
                (SELECT COUNT(*)::int FROM events)                                   AS total_events,
                (SELECT COUNT(*)::int FROM events WHERE status = 'published')        AS published_events,
                (SELECT COUNT(*)::int FROM event_tickets WHERE status <> 'cancelled') AS tickets_sold,
                (SELECT COUNT(*)::int FROM event_tickets WHERE status = 'used')      AS tickets_used,
                (SELECT COALESCE(SUM(price_paid_fc), 0) FROM event_tickets
                   WHERE status IN ('valid','used'))                                 AS revenue_fc
        `);
        res.json(rows[0]);
    } catch (err) {
        console.error('❌ [Billetterie] stats:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Liste des événements (avec vendus et recettes) ──────────────────────────
router.get('/events', async (req, res) => {
    try {
        const { status, q } = req.query;
        const where = [];
        const params = [];
        if (status && EVENT_STATUSES.includes(status)) {
            params.push(status);
            where.push(`e.status = $${params.length}`);
        }
        if (q) {
            params.push(`%${q}%`);
            where.push(`(e.title ILIKE $${params.length} OR e.location ILIKE $${params.length})`);
        }
        const { rows } = await pool.query(`
            SELECT e.*,
                   u.name AS organizer_name,
                   COALESCE(tt.capacity, 0)::int                AS capacity,
                   COALESCE(t.sold, 0)::int                     AS tickets_sold,
                   COALESCE(t.revenue, 0)                       AS revenue_fc
              FROM events e
              LEFT JOIN users u ON u.id = e.organizer_id
              LEFT JOIN (SELECT event_id, SUM(quantity_total) AS capacity
                           FROM event_ticket_types GROUP BY event_id) tt ON tt.event_id = e.id
              LEFT JOIN (SELECT event_id,
                                COUNT(*) FILTER (WHERE status <> 'cancelled') AS sold,
                                SUM(price_paid_fc) FILTER (WHERE status IN ('valid','used')) AS revenue
                           FROM event_tickets GROUP BY event_id) t ON t.event_id = e.id
             ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
             ORDER BY e.event_date DESC, e.id DESC
             LIMIT 200
        `, params);
        res.json(rows);
    } catch (err) {
        console.error('❌ [Billetterie] liste événements:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Créer un événement ──────────────────────────────────────────────────────
router.post('/events', async (req, res) => {
    try {
        const {
            title, subtitle, category, event_date, event_time, location, image_url,
            organizer_id, status, is_free, organizer_phones,
            single_price_fc, single_quantity,
        } = req.body || {};
        if (!title || !event_date || !location) {
            return res.status(400).json({ error: 'Titre, date et lieu sont obligatoires' });
        }
        const cat = CATEGORIES.includes(category) ? category : 'concert';
        const st = EVENT_STATUSES.includes(status) ? status : 'draft';
        const free = is_free === true || is_free === 'true';

        const { rows } = await pool.query(`
            INSERT INTO events (title, subtitle, category, event_date, event_time, location, image_url, organizer_id, status, is_free)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *
        `, [title, subtitle || null, cat, event_date, event_time || null, location,
            image_url || null, organizer_id || null, st, free]);
        const event = rows[0];

        // Organisateurs (numéros de téléphone) : ce sont eux qui scanneront les billets
        const organizers = await setOrganizers(event.id, organizer_phones);

        // Tarif unique : une seule catégorie créée automatiquement
        const price = free ? 0 : parseFloat(single_price_fc);
        if (free || Number.isFinite(price)) {
            const qty = parseInt(single_quantity, 10);
            await pool.query(`
                INSERT INTO event_ticket_types (event_id, name, price_fc, quantity_total)
                VALUES ($1,$2,$3,$4)
            `, [event.id, free ? 'Entrée libre' : 'Standard', free ? 0 : price,
                Number.isInteger(qty) && qty > 0 ? qty : 0]);
        }

        res.status(201).json({ ...event, organizers: organizers.saved, invalid_phones: organizers.invalid });
    } catch (err) {
        console.error('❌ [Billetterie] création événement:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Modifier un événement ───────────────────────────────────────────────────
router.put('/events/:id', async (req, res) => {
    try {
        const { title, subtitle, category, event_date, event_time, location, image_url,
                organizer_id, status, is_free, organizer_phones } = req.body || {};
        if (!title || !event_date || !location) {
            return res.status(400).json({ error: 'Titre, date et lieu sont obligatoires' });
        }
        if (Array.isArray(organizer_phones)) {
            await setOrganizers(req.params.id, organizer_phones);
        }
        const { rows } = await pool.query(`
            UPDATE events SET title=$2, subtitle=$3, category=$4, event_date=$5, event_time=$6,
                              location=$7, image_url=$8, organizer_id=COALESCE($9, organizer_id),
                              status = COALESCE($10, status),
                              is_free = COALESCE($11, is_free), updated_at = NOW()
             WHERE id = $1 RETURNING *
        `, [req.params.id, title, subtitle || null,
            CATEGORIES.includes(category) ? category : 'concert',
            event_date, event_time || null, location, image_url || null, organizer_id || null,
            EVENT_STATUSES.includes(status) ? status : null,
            typeof is_free === 'boolean' ? is_free : null]);
        if (!rows.length) return res.status(404).json({ error: 'Événement introuvable' });
        res.json(rows[0]);
    } catch (err) {
        console.error('❌ [Billetterie] modification événement:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Publier / annuler / clore ───────────────────────────────────────────────
router.patch('/events/:id/status', async (req, res) => {
    try {
        const { status } = req.body || {};
        if (!EVENT_STATUSES.includes(status)) {
            return res.status(400).json({ error: `Statut invalide (${EVENT_STATUSES.join(', ')})` });
        }
        const { rows } = await pool.query(
            'UPDATE events SET status = $2, updated_at = NOW() WHERE id = $1 RETURNING *',
            [req.params.id, status]
        );
        if (!rows.length) return res.status(404).json({ error: 'Événement introuvable' });
        res.json(rows[0]);
    } catch (err) {
        console.error('❌ [Billetterie] statut événement:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Supprimer un événement (refusé si des billets ont été vendus) ───────────
router.delete('/events/:id', async (req, res) => {
    try {
        const sold = await pool.query(
            `SELECT COUNT(*)::int AS n FROM event_tickets WHERE event_id = $1 AND status <> 'cancelled'`,
            [req.params.id]
        );
        if (sold.rows[0].n > 0) {
            return res.status(409).json({
                error: `Suppression impossible : ${sold.rows[0].n} billet(s) vendu(s). Annulez l'événement à la place.`,
            });
        }
        const { rowCount } = await pool.query('DELETE FROM events WHERE id = $1', [req.params.id]);
        if (!rowCount) return res.status(404).json({ error: 'Événement introuvable' });
        res.json({ success: true });
    } catch (err) {
        console.error('❌ [Billetterie] suppression événement:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Catégories de billets d'un événement ────────────────────────────────────
router.get('/events/:id/types', async (req, res) => {
    try {
        const { rows } = await pool.query(
            'SELECT * FROM event_ticket_types WHERE event_id = $1 ORDER BY price_fc DESC, id',
            [req.params.id]
        );
        res.json(rows);
    } catch (err) {
        console.error('❌ [Billetterie] catégories:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.post('/events/:id/types', async (req, res) => {
    try {
        const { name, price_fc, quantity_total } = req.body || {};
        if (!name) return res.status(400).json({ error: 'Nom de catégorie requis' });
        const price = parseFloat(price_fc);
        const qty = parseInt(quantity_total, 10);
        if (!Number.isFinite(price) || price < 0) return res.status(400).json({ error: 'Prix invalide' });
        if (!Number.isInteger(qty) || qty < 0) return res.status(400).json({ error: 'Quantité invalide' });

        const { rows } = await pool.query(`
            INSERT INTO event_ticket_types (event_id, name, price_fc, quantity_total)
            VALUES ($1,$2,$3,$4) RETURNING *
        `, [req.params.id, name, price, qty]);
        res.status(201).json(rows[0]);
    } catch (err) {
        console.error('❌ [Billetterie] création catégorie:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.delete('/types/:id', async (req, res) => {
    try {
        const sold = await pool.query(
            `SELECT COUNT(*)::int AS n FROM event_tickets WHERE ticket_type_id = $1 AND status <> 'cancelled'`,
            [req.params.id]
        );
        if (sold.rows[0].n > 0) {
            return res.status(409).json({ error: `Suppression impossible : ${sold.rows[0].n} billet(s) vendu(s).` });
        }
        const { rowCount } = await pool.query('DELETE FROM event_ticket_types WHERE id = $1', [req.params.id]);
        if (!rowCount) return res.status(404).json({ error: 'Catégorie introuvable' });
        res.json({ success: true });
    } catch (err) {
        console.error('❌ [Billetterie] suppression catégorie:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Ventes (billets émis) ───────────────────────────────────────────────────
router.get('/sales', async (req, res) => {
    try {
        const { event_id, status, q } = req.query;
        const where = [];
        const params = [];
        if (event_id) { params.push(event_id); where.push(`t.event_id = $${params.length}`); }
        if (status && TICKET_STATUSES.includes(status)) { params.push(status); where.push(`t.status = $${params.length}`); }
        if (q) { params.push(`%${q}%`); where.push(`(t.ticket_code ILIKE $${params.length} OR u.name ILIKE $${params.length} OR u.phone ILIKE $${params.length})`); }

        const { rows } = await pool.query(`
            SELECT t.*, e.title AS event_title, e.event_date,
                   tt.name AS type_name,
                   u.name AS buyer_name, u.phone AS buyer_phone
              FROM event_tickets t
              JOIN events e ON e.id = t.event_id
              LEFT JOIN event_ticket_types tt ON tt.id = t.ticket_type_id
              LEFT JOIN users u ON u.id = t.buyer_id
             ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
             ORDER BY t.created_at DESC
             LIMIT 300
        `, params);
        res.json(rows);
    } catch (err) {
        console.error('❌ [Billetterie] ventes:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Marquer un billet (utilisé à l'entrée, annulé, remboursé) ───────────────
router.patch('/tickets/:id/status', async (req, res) => {
    try {
        const { status } = req.body || {};
        if (!TICKET_STATUSES.includes(status)) {
            return res.status(400).json({ error: `Statut invalide (${TICKET_STATUSES.join(', ')})` });
        }
        // Annulation ou remboursement : l'acheteur est recrédité une seule fois.
        if (status === 'refunded' || status === 'cancelled') {
            const client = await pool.connect();
            try {
                await client.query('BEGIN');
                const tRes = await client.query(
                    'SELECT * FROM event_tickets WHERE id = $1 FOR UPDATE',
                    [req.params.id]
                );
                if (!tRes.rows.length) {
                    await client.query('ROLLBACK');
                    return res.status(404).json({ error: 'Billet introuvable' });
                }
                const ticket = tRes.rows[0];
                if (ticket.status === 'refunded' || ticket.status === 'cancelled') {
                    await client.query('ROLLBACK');
                    return res.status(409).json({ error: 'Billet déjà annulé ou remboursé' });
                }

                const amount = parseFloat(ticket.price_paid_fc);
                const reference = `TICKET_REFUND_${ticket.id}`;

                if (ticket.buyer_id && amount > 0) {
                    const dup = await client.query(
                        'SELECT 1 FROM wallet_transactions WHERE reference = $1 LIMIT 1',
                        [reference]
                    );
                    if (!dup.rows.length) {
                        const wallet = await walletRepository._getOrCreateWallet(ticket.buyer_id, client);
                        const before = parseFloat(wallet.balance);
                        const after = before + amount;
                        await client.query('UPDATE wallets SET balance = $1 WHERE id = $2', [after, wallet.id]);
                        await client.query('UPDATE users SET wallet = $1 WHERE id = $2', [after, ticket.buyer_id]);
                        await walletRepository._insertTx(client, {
                            userId: ticket.buyer_id,
                            type: 'refund',
                            amount,
                            balanceBefore: before,
                            balanceAfter: after,
                            provider: 'O_TICKET',
                            reference,
                            description: `Remboursement billet ${ticket.ticket_code}`,
                        });
                    }
                }

                // Le billet libère sa place dans le quota
                if (ticket.ticket_type_id) {
                    await client.query(
                        'UPDATE event_ticket_types SET quantity_sold = GREATEST(quantity_sold - 1, 0) WHERE id = $1',
                        [ticket.ticket_type_id]
                    );
                }

                const upd = await client.query(
                    'UPDATE event_tickets SET status = $2 WHERE id = $1 RETURNING *',
                    [req.params.id, status]
                );
                await client.query('COMMIT');
                return res.json({ ...upd.rows[0], refunded_fc: ticket.buyer_id ? amount : 0 });
            } catch (e) {
                await client.query('ROLLBACK');
                throw e;
            } finally {
                client.release();
            }
        }

        const { rows } = await pool.query(`
            UPDATE event_tickets
               SET status = $2,
                   used_at = CASE WHEN $2 = 'used' THEN NOW() ELSE used_at END
             WHERE id = $1 RETURNING *
        `, [req.params.id, status]);
        if (!rows.length) return res.status(404).json({ error: 'Billet introuvable' });
        res.json(rows[0]);
    } catch (err) {
        console.error('❌ [Billetterie] statut billet:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Émettre des billets manuellement (vente au guichet) ─────────────────────
router.post('/events/:id/issue', async (req, res) => {
    const client = await pool.connect();
    try {
        const { ticket_type_id, quantity, buyer_id, seat_label } = req.body || {};
        const qty = parseInt(quantity, 10) || 1;
        if (qty < 1 || qty > 100) return res.status(400).json({ error: 'Quantité entre 1 et 100' });

        await client.query('BEGIN');

        // Verrou sur la catégorie : empêche de dépasser la capacité
        const typeRes = await client.query(
            'SELECT * FROM event_ticket_types WHERE id = $1 AND event_id = $2 FOR UPDATE',
            [ticket_type_id, req.params.id]
        );
        if (!typeRes.rows.length) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Catégorie de billet introuvable pour cet événement' });
        }
        const type = typeRes.rows[0];
        const remaining = type.quantity_total - type.quantity_sold;
        if (type.quantity_total > 0 && qty > remaining) {
            await client.query('ROLLBACK');
            return res.status(409).json({ error: `Stock insuffisant : ${remaining} billet(s) restant(s)` });
        }

        const created = [];
        for (let i = 0; i < qty; i++) {
            const code = 'TKT-OLI-' + crypto.randomBytes(5).toString('hex').toUpperCase();
            const { rows } = await client.query(`
                INSERT INTO event_tickets (ticket_code, event_id, ticket_type_id, buyer_id, seat_label, price_paid_fc)
                VALUES ($1,$2,$3,$4,$5,$6) RETURNING *
            `, [code, req.params.id, type.id, buyer_id || null, seat_label || null, type.price_fc]);
            created.push(rows[0]);
        }

        await client.query(
            'UPDATE event_ticket_types SET quantity_sold = quantity_sold + $2 WHERE id = $1',
            [type.id, qty]
        );
        await client.query('COMMIT');
        res.status(201).json({ success: true, tickets: created });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('❌ [Billetterie] émission billets:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    } finally {
        client.release();
    }
});

// ─── Organisateurs d'un événement ────────────────────────────────────────────
router.get('/events/:id/organizers', async (req, res) => {
    try {
        const { rows } = await pool.query(`
            SELECT o.id, o.user_id, COALESCE(o.phone, u.phone) AS phone, u.name
              FROM event_organizers o
              JOIN users u ON u.id = o.user_id
             WHERE o.event_id = $1 ORDER BY o.id
        `, [req.params.id]);
        res.json(rows);
    } catch (err) {
        console.error('❌ [Billetterie] organisateurs:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.post('/events/:id/organizers', async (req, res) => {
    try {
        const phones = req.body?.phones ?? [req.body?.phone];
        const result = await setOrganizers(req.params.id, phones);
        if (!result.saved.length) {
            return res.status(400).json({ error: 'Numéro invalide', invalid: result.invalid });
        }
        res.status(201).json(result);
    } catch (err) {
        console.error('❌ [Billetterie] ajout organisateur:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

router.delete('/organizers/:id', async (req, res) => {
    try {
        const { rowCount } = await pool.query('DELETE FROM event_organizers WHERE id = $1', [req.params.id]);
        if (!rowCount) return res.status(404).json({ error: 'Organisateur introuvable' });
        res.json({ success: true });
    } catch (err) {
        console.error('❌ [Billetterie] retrait organisateur:', err.message);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// ─── Téléversement de l'affiche de l'événement ───────────────────────────────
router.post('/upload', genericUpload.single('image'), (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ error: 'Aucun fichier fourni' });
        let imageUrl = req.file.path;
        if (!imageUrl.startsWith('http')) {
            const baseUrl = `${req.protocol}://${req.get('host')}`;
            imageUrl = `${baseUrl}/${req.file.path.replace(/\\/g, '/')}`;
        }
        res.json({ url: imageUrl });
    } catch (err) {
        console.error('❌ [Billetterie] téléversement:', err.message);
        res.status(500).json({ error: "Téléversement impossible" });
    }
});

module.exports = router;
