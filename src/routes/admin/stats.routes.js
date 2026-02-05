/**
 * Routes Admin - Statistiques
 * GET /admin/stats/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');

/**
 * GET /admin/stats/overview
 * Statistiques globales du dashboard
 */
router.get('/overview', async (req, res) => {
    try {
        const { range = '7d' } = req.query;
        let days = 7;
        if (range === '24h') days = 1;
        if (range === '30d') days = 30;
        if (range === '1y') days = 365;

        // Utilisateurs
        const usersStats = await pool.query(`
            SELECT 
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day') as users_today,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '${days} days') as users_period,
                COUNT(*) FILTER (WHERE is_seller = TRUE) as total_sellers
            FROM users
        `);

        // Produits
        const productsStats = await pool.query(`
            SELECT 
                COUNT(*) as total_products,
                COUNT(*) FILTER (WHERE status = 'active') as active_products
            FROM products
        `);

        // Commandes
        let ordersStats = { rows: [{ total_orders: 0, pending_shipping: 0, revenue_total: 0, revenue_today: 0 }] };
        try {
            ordersStats = await pool.query(`
                SELECT 
                    COUNT(*) as total_orders,
                    COUNT(*) FILTER (WHERE status = 'confirmed') as pending_shipping,
                    COALESCE(SUM(total_amount), 0) as revenue_total,
                    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day'), 0) as revenue_today
                FROM orders
                WHERE status != 'cancelled'
            `);
        } catch (e) {
            console.log('Table orders non trouvée');
        }

        // Tickets
        let ticketsStats = { rows: [{ active_disputes: 0 }] };
        try {
            ticketsStats = await pool.query(`
                SELECT COUNT(*) as active_disputes
                FROM support_tickets
                WHERE status IN ('open', 'pending')
            `);
        } catch (e) {
            console.log('Table support_tickets non trouvée');
        }

        // Top Categories (Simulé pour l'instant si pas de table categories liée aux ventes)
        const topCategories = [
            { name: 'Électronique', sales: 1250 },
            { name: 'Mode', sales: 980 },
            { name: 'Maison', sales: 750 },
            { name: 'Beauté', sales: 430 }
        ];

        res.json({
            users: usersStats.rows[0],
            products: productsStats.rows[0],
            orders: ordersStats.rows[0],
            tickets: ticketsStats.rows[0],
            top_categories: topCategories
        });
    } catch (err) {
        console.error('Erreur /admin/stats/overview:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/stats/revenue?period=7d
 * Graphique revenus (par jour)
 */
router.get('/revenue', async (req, res) => {
    try {
        const { period = '30d' } = req.query;
        const days = parseInt(period.replace('d', ''));

        // Simulé pour l'instant (TODO: implémenter vraies commandes)
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
        console.error('Erreur /admin/stats/revenue:', err);
        res.status(500).json({ error: 'Erreur serveur' });
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
        console.error('Erreur /admin/stats/users-growth:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
