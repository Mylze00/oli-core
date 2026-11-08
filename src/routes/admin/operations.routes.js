/**
 * Routes Admin - Journal des opérations
 * GET /admin/operations
 *
 * Réunit les opérations de toutes les applications de l'écosystème Oli.
 * Chaque source est interrogée séparément : si l'une échoue, les autres
 * restent affichées et la source en panne est signalée dans `unavailable`.
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

const APPS = {
    marketplace: 'Marketplace',
    wallet: 'Wallet',
    mobileMoney: 'Mobile Money',
    ticket: 'O-Ticket',
    delivery: 'Livraison',
    seller: 'Vendeurs',
    support: 'Support',
};

// Chaque requête produit les mêmes colonnes pour pouvoir fusionner les résultats.
const SOURCES = [
    {
        key: 'orders', app: APPS.marketplace, label: 'Commande', href: '/orders',
        sql: `SELECT o.id::text AS ref, 'Commande #' || o.id AS title, u.name AS actor_name, u.phone AS actor_phone,
                     o.total_amount::numeric AS amount, 'USD' AS currency, o.status::text AS status, o.created_at::timestamptz AS created_at
              FROM orders o LEFT JOIN users u ON u.id = o.user_id`,
    },
    {
        key: 'wallet', app: APPS.wallet, label: 'Mouvement wallet', href: '/finances',
        // Dépôts/retraits : déjà couverts par Mobile Money. Paiements : par les commandes.
        // Un transfert crée deux lignes : seul le débit est retenu.
        sql: `SELECT wt.id::text AS ref, COALESCE(wt.description, wt.type) AS title, u.name AS actor_name, u.phone AS actor_phone,
                     ABS(wt.amount)::numeric AS amount, wt.currency::text AS currency, wt.status::text AS status, wt.created_at::timestamptz AS created_at
              FROM wallet_transactions wt LEFT JOIN users u ON u.id = wt.user_id
              WHERE wt.user_id <> 0
                AND wt.type NOT IN ('deposit', 'deposit_pending', 'withdrawal', 'withdrawal_pending', 'payment')
                AND NOT (wt.type = 'transfer' AND wt.amount > 0)`,
    },
    {
        key: 'mobile_money', app: APPS.mobileMoney, label: 'Dépôt / retrait', href: '/finances',
        sql: `SELECT uo.oli_order_id::text AS ref,
                     (CASE uo.operation_type WHEN 'deposit' THEN 'Dépôt ' ELSE 'Retrait ' END) || COALESCE(uo.provider, 'Mobile Money') AS title,
                     u.name AS actor_name, COALESCE(u.phone, uo.phone) AS actor_phone,
                     uo.amount_fc::numeric AS amount, 'FC' AS currency, uo.status::text AS status, uo.initiated_at::timestamptz AS created_at
              FROM unipesa_operations uo LEFT JOIN users u ON u.id = uo.user_id`,
    },
    {
        key: 'tickets', app: APPS.ticket, label: 'Billet', href: '/ticketing',
        sql: `SELECT et.ticket_code::text AS ref, 'Billet ' || COALESCE(e.title, '') AS title, u.name AS actor_name, u.phone AS actor_phone,
                     et.price_paid_fc::numeric AS amount, 'FC' AS currency, et.status::text AS status, et.created_at::timestamptz AS created_at
              FROM event_tickets et
              LEFT JOIN events e ON e.id = et.event_id
              LEFT JOIN users u ON u.id = et.buyer_id`,
    },
    {
        key: 'deliveries', app: APPS.delivery, label: 'Livraison', href: '/delivery',
        sql: `SELECT d.id::text AS ref, 'Livraison commande #' || d.order_id AS title, u.name AS actor_name, u.phone AS actor_phone,
                     d.delivery_fee::numeric AS amount, 'USD' AS currency, d.status::text AS status, d.created_at::timestamptz AS created_at
              FROM delivery_orders d LEFT JOIN users u ON u.id = d.deliverer_id`,
    },
    {
        key: 'deliverer_applications', app: APPS.delivery, label: 'Candidature livreur', href: '/delivery',
        sql: `SELECT da.id::text AS ref, 'Candidature livreur' AS title, u.name AS actor_name, COALESCE(u.phone, da.phone) AS actor_phone,
                     da.pledge_amount::numeric AS amount, 'USD' AS currency, da.status::text AS status, da.created_at::timestamptz AS created_at
              FROM deliverer_applications da LEFT JOIN users u ON u.id = da.user_id`,
    },
    {
        key: 'product_requests', app: APPS.marketplace, label: 'Demande de produit', href: '/product-requests',
        sql: `SELECT pr.id::text AS ref, COALESCE(NULLIF(LEFT(pr.description, 120), ''), 'Photo jointe') AS title,
                     COALESCE(NULLIF(NULLIF(pr.user_name, ''), 'Anonyme'), u.name, pr.user_name) AS actor_name,
                     COALESCE(NULLIF(pr.user_phone, ''), u.phone) AS actor_phone, NULL::numeric AS amount, NULL AS currency,
                     pr.status::text AS status, pr.created_at::timestamptz AS created_at
              FROM product_requests pr LEFT JOIN users u ON u.id = pr.user_id`,
    },
    {
        key: 'service_requests', app: APPS.seller, label: 'Demande vendeur', href: '/requests',
        sql: `SELECT sr.id::text AS ref,
                     CASE sr.request_type WHEN 'shop_certification' THEN 'Certification de boutique'
                          WHEN 'product_sponsorship' THEN 'Sponsoring de produit'
                          WHEN 'user_verification' THEN 'Vérification d''identité'
                          ELSE sr.request_type::text END AS title, u.name AS actor_name, u.phone AS actor_phone,
                     NULL::numeric AS amount, NULL AS currency, sr.status::text AS status, sr.created_at::timestamptz AS created_at
              FROM service_requests sr LEFT JOIN users u ON u.id = sr.user_id`,
    },
    {
        key: 'support', app: APPS.support, label: 'Ticket support', href: '/support',
        sql: `SELECT st.id::text AS ref, st.subject::text AS title, u.name AS actor_name, u.phone AS actor_phone,
                     NULL::numeric AS amount, NULL AS currency, st.status::text AS status, st.created_at::timestamptz AS created_at
              FROM support_tickets st LEFT JOIN users u ON u.id = st.user_id`,
    },
    {
        key: 'disputes', app: APPS.support, label: 'Litige', href: '/disputes',
        sql: `SELECT d.id::text AS ref, d.reason::text AS title, u.name AS actor_name, u.phone AS actor_phone,
                     NULL::numeric AS amount, NULL AS currency, d.status::text AS status, d.created_at::timestamptz AS created_at
              FROM disputes d LEFT JOIN users u ON u.id = d.reporter_id`,
    },
];

const STATUS_GROUPS = {
    todo: ['pending', 'open', 'processing', 'reviewed', 'paid', 'assigned', 'accepted', 'picked_up', 'in_transit', 'shipped'],
    done: ['completed', 'success', 'delivered', 'resolved', 'responded', 'closed', 'used', 'valid', 'approved'],
    failed: ['failed', 'cancelled', 'canceled', 'timeout', 'rejected', 'refunded', 'reversed'],
};

const RANGES = { '24h': '1 day', '7d': '7 days', '30d': '30 days', '90d': '90 days' };
const MAX_PAGE_SIZE = 100;

function groupOf(status) {
    return Object.keys(STATUS_GROUPS).find((g) => STATUS_GROUPS[g].includes(status)) || 'other';
}

router.get('/', async (req, res) => {
    try {
        const interval = RANGES[req.query.range] || RANGES['7d'];
        const statuses = STATUS_GROUPS[req.query.status] || null;
        const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
        const pageSize = Math.min(Math.max(parseInt(req.query.pageSize, 10) || 25, 1), MAX_PAGE_SIZE);
        const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
        const search = q ? `%${q.replace(/[\\%_]/g, '\\$&')}%` : null;

        const where = `WHERE created_at >= NOW() - $1::interval
            AND ($2::text IS NULL OR title ILIKE $2 OR ref ILIKE $2 OR actor_name ILIKE $2 OR actor_phone ILIKE $2)`;
        const params = [interval, search];
        const needed = page * pageSize; // une page peut venir entièrement d'une seule source

        // Les chiffres par application restent visibles quand un filtre d'application est actif.
        const results = await Promise.allSettled(SOURCES.map(async (source) => {
            const [counts, rows] = await Promise.all([
                pool.query(`SELECT status, COUNT(*)::int AS n FROM (${source.sql}) s ${where} GROUP BY status`, params),
                (req.query.app && req.query.app !== source.app)
                    ? Promise.resolve({ rows: [] })
                    : pool.query(
                        `SELECT * FROM (${source.sql}) s ${where} AND ($3::text[] IS NULL OR status = ANY($3))
                         ORDER BY created_at DESC LIMIT $4`,
                        [...params, statuses, needed]
                    ),
            ]);
            return { source, counts: counts.rows, rows: rows.rows };
        }));

        const summary = { total: 0, todo: 0, done: 0, failed: 0, other: 0 };
        const byApp = {};
        let items = [];
        let total = 0;
        const unavailable = [];

        results.forEach((result, i) => {
            if (result.status === 'rejected') {
                console.warn(`[OPERATIONS] Source ${SOURCES[i].key} indisponible:`, result.reason.message);
                unavailable.push(SOURCES[i].label);
                return;
            }
            const { source, counts, rows } = result.value;
            const selected = !req.query.app || req.query.app === source.app;
            for (const { status, n } of counts) {
                byApp[source.app] = (byApp[source.app] || 0) + n;
                if (!selected) continue;
                const group = groupOf(status);
                summary.total += n;
                summary[group] += n;
                if (!statuses || statuses.includes(status)) total += n;
            }
            items.push(...rows.map((row) => ({
                id: `${source.key}-${row.ref}`,
                source: source.key,
                app: source.app,
                label: source.label,
                href: source.href,
                ref: row.ref,
                title: row.title,
                actorName: row.actor_name,
                actorPhone: row.actor_phone,
                amount: row.amount === null ? null : parseFloat(row.amount),
                currency: row.currency,
                status: row.status,
                statusGroup: groupOf(row.status),
                createdAt: row.created_at,
            })));
        });

        items.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        items = items.slice((page - 1) * pageSize, page * pageSize);

        res.json({
            items,
            total,
            page,
            pageSize,
            summary,
            apps: Object.values(APPS).map((name) => ({ name, total: byApp[name] || 0 })),
            unavailable,
        });
    } catch (err) {
        console.error('Erreur GET /admin/operations:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
