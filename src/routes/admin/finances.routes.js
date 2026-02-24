/**
 * Routes Admin - Finances & Revenus
 * GET /admin/finances/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/finances/overview
 * Vue globale des finances : revenus, wallets, commandes payées
 */
router.get('/overview', async (req, res) => {
    try {
        const { range = '30d' } = req.query;
        const days = parseInt(range.replace('d', '')) || 30;

        // Revenus commandes
        let revenueStats = { total: 0, period: 0, paid: 0, pending: 0, avg: 0 };
        try {
            const r = await pool.query(`
                SELECT 
                    COALESCE(SUM(total_amount), 0) as total,
                    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days'), 0) as period,
                    COUNT(*) FILTER (WHERE payment_status = 'completed') as paid,
                    COUNT(*) FILTER (WHERE payment_status = 'pending' OR payment_status IS NULL) as pending_payment,
                    COALESCE(AVG(total_amount), 0) as avg_order
                FROM orders WHERE status != 'cancelled'
            `);
            const row = r.rows[0];
            revenueStats = {
                total: parseFloat(row.total),
                period: parseFloat(row.period),
                paid: parseInt(row.paid),
                pending: parseInt(row.pending_payment),
                avg: parseFloat(row.avg_order),
            };
        } catch (e) { console.warn('[finances] orders:', e.message); }

        // Wallets utilisateurs
        let walletStats = { total_balance: 0, avg_balance: 0, users_with_balance: 0 };
        try {
            const w = await pool.query(`
                SELECT
                    COALESCE(SUM(wallet), 0) as total_balance,
                    COALESCE(AVG(wallet) FILTER (WHERE wallet > 0), 0) as avg_balance,
                    COUNT(*) FILTER (WHERE wallet > 0) as users_with_balance
                FROM users WHERE is_admin IS NULL OR is_admin = FALSE
            `);
            const row = w.rows[0];
            walletStats = {
                total_balance: parseFloat(row.total_balance),
                avg_balance: parseFloat(row.avg_balance),
                users_with_balance: parseInt(row.users_with_balance),
            };
        } catch (e) { console.warn('[finances] wallets:', e.message); }

        res.json({ revenue: revenueStats, wallets: walletStats, period_days: days });
    } catch (err) {
        console.error('Erreur /admin/finances/overview:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/finances/revenue-chart?days=30
 * Données pour le graphique revenus par jour
 */
router.get('/revenue-chart', async (req, res) => {
    try {
        const days = parseInt(req.query.days) || 30;
        const result = await pool.query(`
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as orders_count,
                COALESCE(SUM(total_amount), 0) as revenue
            FROM orders
            WHERE created_at >= NOW() - INTERVAL '${days} days'
            AND status != 'cancelled'
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        `);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur /admin/finances/revenue-chart:', err);
        res.json([]);
    }
});

/**
 * GET /admin/finances/top-sellers?limit=10
 * Top vendeurs par chiffre d'affaires
 */
router.get('/top-sellers', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const result = await pool.query(`
            SELECT 
                u.id, u.name, u.phone, u.avatar_url,
                u.has_certified_shop,
                COUNT(o.id) as orders_count,
                COALESCE(SUM(o.total_amount), 0) as total_revenue
            FROM orders o
            JOIN users u ON o.seller_id = u.id
            WHERE o.status != 'cancelled'
            GROUP BY u.id
            ORDER BY total_revenue DESC
            LIMIT $1
        `, [limit]);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur /admin/finances/top-sellers:', err);
        res.json([]);
    }
});

/**
 * GET /admin/finances/transactions?limit=50
 * Dernières commandes (transactions)
 */
router.get('/transactions', async (req, res) => {
    try {
        const { limit = 50, offset = 0, status } = req.query;
        let query = `
            SELECT 
                o.id, o.total_amount, o.payment_status, o.status,
                o.created_at, o.payment_method,
                u.name as buyer_name, u.phone as buyer_phone,
                s.name as seller_name
            FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            LEFT JOIN users s ON o.seller_id = s.id
            WHERE 1=1
        `;
        const params = [];
        let idx = 1;
        if (status && status !== 'all') {
            query += ` AND o.payment_status = $${idx++}`;
            params.push(status);
        }
        query += ` ORDER BY o.created_at DESC LIMIT $${idx++} OFFSET $${idx}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Erreur /admin/finances/transactions:', err);
        res.json([]);
    }
});

module.exports = router;
