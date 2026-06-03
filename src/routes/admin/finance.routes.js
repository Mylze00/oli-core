/**
 * Routes Admin — Finance & Wallets OLI
 * Préfixe : /api/admin/finance
 * Accès : Admin uniquement (middleware appliqué dans server.js)
 */
const express = require('express');
const router  = express.Router();
const pool    = require('../../config/db');

// ─── KPI Vue Globale ─────────────────────────────────────────────────────────
// GET /api/admin/finance/overview
router.get('/overview', async (req, res) => {
    try {
        const [circ, fees, vol24h, active, unipesa, byType] = await Promise.all([
            pool.query('SELECT COALESCE(SUM(balance),0) as total FROM wallets WHERE user_id != 0'),
            pool.query('SELECT COALESCE(balance,0) as total FROM wallets WHERE user_id = 0'),
            pool.query(`SELECT COALESCE(SUM(ABS(amount)),0) as vol 
                        FROM wallet_transactions 
                        WHERE created_at >= NOW() - INTERVAL '24 hours'`),
            pool.query('SELECT COUNT(*) as cnt FROM wallets WHERE balance > 0 AND user_id != 0'),
            pool.query(`
                SELECT 
                    COUNT(*) FILTER (WHERE status = 'success') as success_count,
                    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
                    COALESCE(SUM(amount_fc) FILTER (WHERE status = 'success'), 0) as total_deposited
                FROM unipesa_operations WHERE operation_type = 'deposit'
            `),
            pool.query(`
                SELECT type, 
                    COUNT(*) as count,
                    COALESCE(SUM(ABS(amount)),0) as volume
                FROM wallet_transactions
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY type
                ORDER BY volume DESC
            `),
        ]);

        res.json({
            success: true,
            fcInCirculation:  parseFloat(circ.rows[0].total),
            feesCollectedFC:  parseFloat(fees.rows[0].total),
            volume24hFC:      parseFloat(vol24h.rows[0].vol),
            activeWallets:    parseInt(active.rows[0].cnt),
            unipesa: {
                totalDepositsSuccess: parseInt(unipesa.rows[0].success_count),
                totalDepositsPending: parseInt(unipesa.rows[0].pending_count),
                totalDepositedFC:     parseFloat(unipesa.rows[0].total_deposited),
            },
            volumeByType: byType.rows.map(r => ({
                type:   r.type,
                count:  parseInt(r.count),
                volume: parseFloat(r.volume),
            })),
        });
    } catch (err) {
        console.error('Admin Finance overview:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ─── Toutes les transactions wallet ──────────────────────────────────────────
// GET /api/admin/finance/transactions?type=&user_id=&search=&limit=50&offset=0
router.get('/transactions', async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit)  || 50, 200);
        const offset = parseInt(req.query.offset) || 0;
        const type   = req.query.type;
        const userId = req.query.user_id;
        const search = req.query.search;

        const whereParts = [];
        const params     = [];
        let   idx        = 1;

        if (type)   { whereParts.push(`wt.type = $${idx++}`);    params.push(type); }
        if (userId) { whereParts.push(`wt.user_id = $${idx++}`); params.push(parseInt(userId)); }
        if (search) {
            whereParts.push(`(u.name ILIKE $${idx} OR u.phone ILIKE $${idx})`);
            params.push(`%${search}%`);
            idx++;
        }

        const whereSQL = whereParts.length ? 'WHERE ' + whereParts.join(' AND ') : '';

        const txResult = await pool.query(`
            SELECT 
                wt.id, wt.user_id, wt.type, wt.amount, wt.balance_before, wt.balance_after,
                wt.currency, wt.provider, wt.reference, wt.description, wt.status, wt.created_at,
                u.name    as user_name,
                u.phone   as user_phone,
                u.role    as user_role
            FROM wallet_transactions wt
            LEFT JOIN users u ON wt.user_id = u.id
            ${whereSQL}
            ORDER BY wt.created_at DESC
            LIMIT $${idx++} OFFSET $${idx++}
        `, [...params, limit, offset]);

        const countResult = await pool.query(
            `SELECT COUNT(*) FROM wallet_transactions wt LEFT JOIN users u ON wt.user_id = u.id ${whereSQL}`,
            params
        );

        res.json({
            success:      true,
            transactions: txResult.rows.map(tx => ({
                ...tx,
                amount:         parseFloat(tx.amount),
                balance_before: parseFloat(tx.balance_before),
                balance_after:  parseFloat(tx.balance_after),
            })),
            total: parseInt(countResult.rows[0].count),
            limit, offset,
        });
    } catch (err) {
        console.error('Admin Finance transactions:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ─── Wallet d'un utilisateur spécifique ──────────────────────────────────────
// GET /api/admin/finance/users/:id/wallet
router.get('/users/:id/wallet', async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        const [wallet, txs, user, stats] = await Promise.all([
            pool.query('SELECT * FROM wallets WHERE user_id = $1', [userId]),
            pool.query(`
                SELECT * FROM wallet_transactions 
                WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20
            `, [userId]),
            pool.query('SELECT id, name, phone, role FROM users WHERE id = $1', [userId]),
            pool.query(`
                SELECT 
                    COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END), 0)             as total_deposited,
                    COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN ABS(amount) ELSE 0 END), 0)    as total_withdrawn,
                    COALESCE(SUM(CASE WHEN type = 'transfer' AND amount > 0 THEN amount ELSE 0 END), 0) as total_received,
                    COALESCE(SUM(CASE WHEN type = 'transfer' AND amount < 0 THEN ABS(amount) ELSE 0 END), 0) as total_sent,
                    COALESCE(SUM(CASE WHEN type = 'payment' THEN ABS(amount) ELSE 0 END), 0)       as total_purchases,
                    COALESCE(SUM(CASE WHEN type IN ('credit','reward') THEN amount ELSE 0 END), 0)  as total_earned,
                    COUNT(*) as tx_count
                FROM wallet_transactions WHERE user_id = $1
            `, [userId]),
        ]);

        if (!wallet.rows.length) {
            return res.status(404).json({ success: false, error: 'Wallet introuvable' });
        }

        res.json({
            success: true,
            user:   user.rows[0],
            wallet: { ...wallet.rows[0], balance: parseFloat(wallet.rows[0].balance) },
            stats:  stats.rows[0],
            recentTransactions: txs.rows.map(tx => ({
                ...tx,
                amount:        parseFloat(tx.amount),
                balance_after: parseFloat(tx.balance_after),
            })),
        });
    } catch (err) {
        console.error('Admin Finance user wallet:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ─── Geler / Dégeler un wallet ────────────────────────────────────────────────
// POST /api/admin/finance/users/:id/freeze
router.post('/users/:id/freeze', async (req, res) => {
    try {
        const userId  = parseInt(req.params.id);
        const freeze  = Boolean(req.body.freeze);
        const reason  = req.body.reason || (freeze ? 'Gel administrateur' : 'Dégel administrateur');

        await pool.query('UPDATE wallets SET is_frozen = $1 WHERE user_id = $2', [freeze, userId]);

        console.log(`🔒 Admin: wallet user #${userId} ${freeze ? 'GEL' : 'DÉGEL'} — ${reason}`);

        res.json({
            success:   true,
            message:   `Wallet user #${userId} ${freeze ? 'gelé' : 'dégelé'} avec succès`,
            is_frozen: freeze,
        });
    } catch (err) {
        console.error('Admin Finance freeze:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ─── Opérations Unipesa ───────────────────────────────────────────────────────
// GET /api/admin/finance/unipesa?status=&limit=50&offset=0
router.get('/unipesa', async (req, res) => {
    try {
        const limit  = Math.min(parseInt(req.query.limit) || 50, 200);
        const offset = parseInt(req.query.offset) || 0;
        const status = req.query.status;

        const params = [];
        let where    = '';
        let idx      = 1;
        if (status) { where = `WHERE uo.status = $${idx++}`; params.push(status); }
        params.push(limit, offset);

        const result = await pool.query(`
            SELECT uo.*, u.name as user_name, u.phone as user_phone
            FROM unipesa_operations uo
            LEFT JOIN users u ON uo.user_id = u.id
            ${where}
            ORDER BY uo.created_at DESC
            LIMIT $${idx++} OFFSET $${idx++}
        `, params);

        res.json({ success: true, operations: result.rows, limit, offset });
    } catch (err) {
        console.error('Admin Finance unipesa:', err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// ─── Résumé stats par utilisateur ────────────────────────────────────────────
// GET /api/admin/finance/summary/:id
router.get('/summary/:id', async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        const stats  = await pool.query(`
            SELECT 
                COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END), 0)             as total_deposited,
                COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN ABS(amount) ELSE 0 END), 0)    as total_withdrawn,
                COALESCE(SUM(CASE WHEN type = 'transfer' AND amount > 0 THEN amount ELSE 0 END), 0) as total_received,
                COALESCE(SUM(CASE WHEN type = 'transfer' AND amount < 0 THEN ABS(amount) ELSE 0 END), 0) as total_sent,
                COALESCE(SUM(CASE WHEN type = 'payment' THEN ABS(amount) ELSE 0 END), 0)       as total_purchases,
                COALESCE(SUM(CASE WHEN type IN ('credit','reward') THEN amount ELSE 0 END), 0)  as total_earned,
                COUNT(*) as tx_count
            FROM wallet_transactions WHERE user_id = $1
        `, [userId]);

        res.json({ success: true, stats: stats.rows[0] });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
