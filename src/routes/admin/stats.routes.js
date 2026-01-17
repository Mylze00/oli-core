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
        // Utilisateurs
        const usersStats = await pool.query(`
            SELECT 
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day') as users_today,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as users_this_week,
                COUNT(*) FILTER (WHERE is_seller = TRUE) as total_sellers,
                COUNT(*) FILTER (WHERE is_deliverer = TRUE) as total_deliverers
            FROM users
        `);

        // Produits
        const productsStats = await pool.query(`
            SELECT 
                COUNT(*) as total_products,
                COUNT(*) FILTER (WHERE status = 'active') as active_products,
                COUNT(*) FILTER (WHERE is_featured = TRUE) as featured_products,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day') as products_today
            FROM products
        `);

        // Commandes (si table existe)
        let ordersStats = { rows: [{ total_orders: 0, pending_orders: 0, completed_orders: 0, revenue_today: 0 }] };
        try {
            ordersStats = await pool.query(`
                SELECT 
                    COUNT(*) as total_orders,
                    COUNT(*) FILTER (WHERE status = 'pending') as pending_orders,
                    COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
                    COALESCE(SUM(total_amount) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day'), 0) as revenue_today
                FROM orders
            `);
        } catch (e) {
            console.log('Table orders non trouvée, valeurs par défaut utilisées');
        }

        res.json({
            users: usersStats.rows[0],
            products: productsStats.rows[0],
            orders: ordersStats.rows[0]
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
                0 as revenue
            FROM products
            WHERE created_at >= NOW() - INTERVAL '${days} days'
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
