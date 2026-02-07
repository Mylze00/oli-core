/**
 * Routes Admin - Statistiques enrichies
 * GET /admin/stats/*
 * Connecté à l'ensemble de l'écosystème Oli
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/stats/overview
 * Statistiques globales enrichies du dashboard
 */
router.get('/overview', async (req, res) => {
    try {
        const { range = '7d' } = req.query;
        let days = 7;
        if (range === '24h') days = 1;
        if (range === '30d') days = 30;
        if (range === '1y') days = 365;

        // ─── UTILISATEURS ───
        const usersStats = await pool.query(`
            SELECT 
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days') as users_period,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days * 2} days' AND created_at < NOW() - INTERVAL '${days} days') as users_prev_period,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day') as users_today,
                COUNT(*) FILTER (WHERE is_seller = TRUE) as total_sellers,
                COUNT(*) FILTER (WHERE is_admin = TRUE) as total_admins
            FROM users
        `);

        // ─── PRODUITS ───
        const productsStats = await pool.query(`
            SELECT 
                COUNT(*) as total_products,
                COUNT(*) FILTER (WHERE status = 'active' OR status IS NULL) as active_products,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days') as products_period,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days * 2} days' AND created_at < NOW() - INTERVAL '${days} days') as products_prev_period
            FROM products
        `);

        // ─── COMMANDES & REVENUS ───
        let ordersStats = { rows: [{ total_orders: 0, orders_period: 0, orders_prev_period: 0, pending_shipping: 0, revenue_total: 0, revenue_period: 0, revenue_prev_period: 0, paid_orders: 0 }] };
        try {
            ordersStats = await pool.query(`
                SELECT 
                    COUNT(*) as total_orders,
                    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days') as orders_period,
                    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days * 2} days' AND created_at < NOW() - INTERVAL '${days} days') as orders_prev_period,
                    COUNT(*) FILTER (WHERE status = 'confirmed' OR status = 'pending') as pending_shipping,
                    COALESCE(SUM(total_amount), 0) as revenue_total,
                    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days'), 0) as revenue_period,
                    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '${days * 2} days' AND created_at < NOW() - INTERVAL '${days} days'), 0) as revenue_prev_period,
                    COUNT(*) FILTER (WHERE payment_status = 'completed') as paid_orders
                FROM orders
                WHERE status != 'cancelled'
            `);
        } catch (e) {
            console.log('[STATS] Table orders indisponible:', e.message);
        }

        // ─── BOUTIQUES ───
        let shopsStats = { rows: [{ total_shops: 0, shops_period: 0 }] };
        try {
            shopsStats = await pool.query(`
                SELECT 
                    COUNT(*) as total_shops,
                    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days') as shops_period
                FROM shops
            `);
        } catch (e) {
            console.log('[STATS] Table shops indisponible:', e.message);
        }

        // ─── CONVERSATIONS & MESSAGES ───
        let chatStats = { rows: [{ total_conversations: 0, messages_period: 0 }] };
        try {
            const convCount = await pool.query(`SELECT COUNT(*) as total FROM conversations`);
            const msgCount = await pool.query(`
                SELECT COUNT(*) as count 
                FROM messages 
                WHERE created_at >= NOW() - INTERVAL '${days} days'
            `);
            chatStats = { rows: [{ total_conversations: parseInt(convCount.rows[0].total), messages_period: parseInt(msgCount.rows[0].count) }] };
        } catch (e) {
            console.log('[STATS] Tables chat indisponibles:', e.message);
        }

        // ─── LIVRAISONS ───
        let deliveryStats = { rows: [{ pending_deliveries: 0, completed_deliveries: 0 }] };
        try {
            deliveryStats = await pool.query(`
                SELECT 
                    COUNT(*) FILTER (WHERE status IN ('assigned', 'picked_up', 'in_transit')) as pending_deliveries,
                    COUNT(*) FILTER (WHERE status = 'delivered') as completed_deliveries
                FROM delivery_orders
            `);
        } catch (e) {
            console.log('[STATS] Table delivery_orders indisponible:', e.message);
        }

        // ─── TICKETS SUPPORT ───
        let ticketsStats = { rows: [{ active_disputes: 0, total_tickets: 0 }] };
        try {
            ticketsStats = await pool.query(`
                SELECT 
                    COUNT(*) FILTER (WHERE status IN ('open', 'pending')) as active_disputes,
                    COUNT(*) as total_tickets
                FROM support_tickets
            `);
        } catch (e) {
            console.log('[STATS] Table support_tickets indisponible:', e.message);
        }

        // ─── TOP CATÉGORIES (VRAIES DONNÉES) ───
        let topCategories = [];
        try {
            const catResult = await pool.query(`
                SELECT 
                    COALESCE(category, 'Non catégorisé') as name,
                    COUNT(*) as product_count
                FROM products
                WHERE category IS NOT NULL AND category != ''
                GROUP BY category
                ORDER BY product_count DESC
                LIMIT 6
            `);
            topCategories = catResult.rows.map(r => ({
                name: r.name,
                count: parseInt(r.product_count)
            }));
        } catch (e) {
            console.log('[STATS] Catégories indisponibles:', e.message);
        }

        // ─── CALCUL DES TENDANCES ───
        const users = usersStats.rows[0];
        const products = productsStats.rows[0];
        const orders = ordersStats.rows[0];

        const calcTrend = (current, previous) => {
            const c = parseInt(current) || 0;
            const p = parseInt(previous) || 0;
            if (p === 0) return c > 0 ? 100 : 0;
            return Math.round(((c - p) / p) * 100);
        };

        res.json({
            users: {
                total: parseInt(users.total_users),
                period: parseInt(users.users_period),
                today: parseInt(users.users_today),
                sellers: parseInt(users.total_sellers),
                admins: parseInt(users.total_admins),
                trend: calcTrend(users.users_period, users.users_prev_period),
            },
            products: {
                total: parseInt(products.total_products),
                active: parseInt(products.active_products),
                period: parseInt(products.products_period),
                trend: calcTrend(products.products_period, products.products_prev_period),
            },
            orders: {
                total: parseInt(orders.total_orders),
                period: parseInt(orders.orders_period),
                pending_shipping: parseInt(orders.pending_shipping),
                revenue_total: parseFloat(orders.revenue_total),
                revenue_period: parseFloat(orders.revenue_period),
                revenue_trend: calcTrend(orders.revenue_period, orders.revenue_prev_period),
                orders_trend: calcTrend(orders.orders_period, orders.orders_prev_period),
                paid: parseInt(orders.paid_orders),
            },
            shops: {
                total: parseInt(shopsStats.rows[0].total_shops),
                period: parseInt(shopsStats.rows[0].shops_period),
            },
            chat: chatStats.rows[0],
            deliveries: {
                pending: parseInt(deliveryStats.rows[0].pending_deliveries),
                completed: parseInt(deliveryStats.rows[0].completed_deliveries),
            },
            tickets: {
                active: parseInt(ticketsStats.rows[0].active_disputes),
                total: parseInt(ticketsStats.rows[0].total_tickets),
            },
            top_categories: topCategories,
        });
    } catch (err) {
        console.error('❌ Erreur /admin/stats/overview:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/stats/revenue?period=30d
 * Graphique revenus (par jour)
 */
router.get('/revenue', async (req, res) => {
    try {
        const { period = '30d' } = req.query;
        const days = parseInt(period.replace('d', '')) || 30;

        const revenue = await pool.query(`
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

        res.json(revenue.rows);
    } catch (err) {
        console.error('❌ Erreur /admin/stats/revenue:', err);
        // Retourner tableau vide au lieu d'erreur 500
        res.json([]);
    }
});

/**
 * GET /admin/stats/users-growth
 * Croissance utilisateurs par jour
 */
router.get('/users-growth', async (req, res) => {
    try {
        const growth = await pool.query(`
            SELECT 
                DATE(created_at) as date,
                COUNT(*) as new_users
            FROM users
            WHERE created_at >= NOW() - INTERVAL '30 days'
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        `);

        res.json(growth.rows);
    } catch (err) {
        console.error('❌ Erreur /admin/stats/users-growth:', err);
        res.json([]);
    }
});

/**
 * GET /admin/stats/activity
 * Activité récente en temps réel
 */
router.get('/activity', async (req, res) => {
    try {
        const activities = [];

        // Derniers utilisateurs inscrits
        try {
            const users = await pool.query(`
                SELECT id, name, phone, created_at, 'user_registered' as type
                FROM users ORDER BY created_at DESC LIMIT 5
            `);
            activities.push(...users.rows);
        } catch (e) { }

        // Dernières commandes
        try {
            const orders = await pool.query(`
                SELECT o.id, o.total_amount, o.status, o.created_at, 
                       'order_created' as type, u.name as user_name
                FROM orders o LEFT JOIN users u ON o.user_id = u.id
                ORDER BY o.created_at DESC LIMIT 5
            `);
            activities.push(...orders.rows);
        } catch (e) { }

        // Derniers produits ajoutés
        try {
            const products = await pool.query(`
                SELECT p.id, p.name, p.price, p.created_at,
                       'product_added' as type, u.name as seller_name
                FROM products p LEFT JOIN users u ON p.seller_id = u.id
                ORDER BY p.created_at DESC LIMIT 5
            `);
            activities.push(...products.rows);
        } catch (e) { }

        // Dernières boutiques créées
        try {
            const shops = await pool.query(`
                SELECT s.id, s.name, s.created_at,
                       'shop_created' as type, u.name as owner_name
                FROM shops s LEFT JOIN users u ON s.owner_id = u.id
                ORDER BY s.created_at DESC LIMIT 3
            `);
            activities.push(...shops.rows);
        } catch (e) { }

        // Trier par date et limiter
        activities.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

        res.json(activities.slice(0, 15));
    } catch (err) {
        console.error('❌ Erreur /admin/stats/activity:', err);
        res.json([]);
    }
});

module.exports = router;
