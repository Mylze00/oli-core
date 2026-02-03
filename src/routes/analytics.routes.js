/**
 * Routes Analytics Vendeur
 * Endpoints pour les statistiques avancées OLI Seller
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const sellerRepo = require('../repositories/seller.repository');
const { requireAuth } = require('../middlewares/auth.middleware');

/**
 * Middleware pour vérifier que l'utilisateur est vendeur
 */
const requireSeller = (req, res, next) => {
    if (!req.user.is_seller) {
        return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
    }
    next();
};

/**
 * GET /api/analytics/overview
 * Vue d'ensemble complète des analytics
 * Combine les stats de base et les KPIs avancés
 */
router.get('/overview', requireAuth, requireSeller, async (req, res) => {
    try {
        const [basic, advanced] = await Promise.all([
            sellerRepo.getSellerDashboard(req.user.id),
            sellerRepo.getAdvancedAnalytics(req.user.id)
        ]);

        res.json({
            // Stats de base
            total_products: basic.total_products,
            active_products: basic.active_products,
            orders_this_month: basic.orders_this_month,
            pending_orders: basic.pending_orders,
            revenue_this_month: basic.revenue_this_month,
            total_revenue: basic.total_revenue,
            total_sales: basic.total_sales,

            // KPIs avancés
            total_views: advanced.total_views,
            average_cart: advanced.average_cart,
            conversion_rate: advanced.conversion_rate,
            completed_orders: advanced.completed_orders,

            period: 'month',
            updated_at: new Date().toISOString()
        });
    } catch (error) {
        console.error('Error GET /api/analytics/overview:', error);
        res.status(500).json({ error: 'Erreur récupération analytics' });
    }
});

/**
 * GET /api/analytics/top-products
 * Top N produits les plus vendus
 */
router.get('/top-products', requireAuth, requireSeller, async (req, res) => {
    try {
        const { limit = 10 } = req.query;
        const products = await sellerRepo.getTopProducts(req.user.id, parseInt(limit));
        res.json(products);
    } catch (error) {
        console.error('Error GET /api/analytics/top-products:', error);
        res.status(500).json({ error: 'Erreur récupération top produits' });
    }
});

/**
 * GET /api/analytics/products-without-sales
 * Produits sans ventes récentes (à optimiser)
 */
router.get('/products-without-sales', requireAuth, requireSeller, async (req, res) => {
    try {
        const { days = 30 } = req.query;
        const products = await sellerRepo.getProductsWithoutSales(req.user.id, parseInt(days));
        res.json(products);
    } catch (error) {
        console.error('Error GET /api/analytics/products-without-sales:', error);
        res.status(500).json({ error: 'Erreur récupération produits sans ventes' });
    }
});

/**
 * GET /api/analytics/recent-orders
 * Dernières commandes (widget dashboard)
 */
router.get('/recent-orders', requireAuth, requireSeller, async (req, res) => {
    try {
        const { limit = 5 } = req.query;
        const orders = await sellerRepo.getRecentOrders(req.user.id, parseInt(limit));
        res.json(orders);
    } catch (error) {
        console.error('Error GET /api/analytics/recent-orders:', error);
        res.status(500).json({ error: 'Erreur récupération commandes récentes' });
    }
});

/**
 * GET /api/analytics/sales-chart
 * Données pour graphique des ventes (7j, 30j, 12m)
 */
router.get('/sales-chart', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '7d' } = req.query;

        if (!['7d', '30d', '12m'].includes(period)) {
            return res.status(400).json({ error: 'Période invalide. Utilisez 7d, 30d ou 12m' });
        }

        const data = await sellerRepo.getSalesChart(req.user.id, period);
        res.json({
            period,
            data,
            labels: data.map(d => d.date),
            values: data.map(d => parseFloat(d.revenue) || 0)
        });
    } catch (error) {
        console.error('Error GET /api/analytics/sales-chart:', error);
        res.status(500).json({ error: 'Erreur récupération graphique ventes' });
    }
});

module.exports = router;
