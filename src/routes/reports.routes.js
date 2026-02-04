/**
 * Routes Rapports Avancés
 * Génération de rapports détaillés et exports PDF
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const db = require('../config/db');

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
 * Helper pour parser les dates de période
 */
const getPeriodDates = (period) => {
    const now = new Date();
    let startDate;

    switch (period) {
        case '7d':
            startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            break;
        case '30d':
            startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
            break;
        case '90d':
            startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
            break;
        case '12m':
            startDate = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
            break;
        default:
            startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    }

    return { startDate, endDate: now };
};

/**
 * GET /reports/sales - Rapport des ventes
 */
router.get('/sales', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '30d', start_date, end_date } = req.query;

        let startDate, endDate;
        if (start_date && end_date) {
            startDate = new Date(start_date);
            endDate = new Date(end_date);
        } else {
            const dates = getPeriodDates(period);
            startDate = dates.startDate;
            endDate = dates.endDate;
        }

        // Ventes par jour
        const salesByDayQuery = `
            SELECT 
                DATE(o.created_at) as date,
                COUNT(DISTINCT o.id) as orders,
                SUM(oi.product_price * oi.quantity) as revenue,
                SUM(oi.quantity) as items_sold
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
              AND o.status NOT IN ('cancelled')
              AND o.created_at BETWEEN $2 AND $3
            GROUP BY DATE(o.created_at)
            ORDER BY date
        `;
        const salesByDay = await db.query(salesByDayQuery, [req.user.id, startDate, endDate]);

        // Totaux
        const totalsQuery = `
            SELECT 
                COUNT(DISTINCT o.id) as total_orders,
                COALESCE(SUM(oi.product_price * oi.quantity), 0) as total_revenue,
                COALESCE(SUM(oi.quantity), 0) as total_items,
                COALESCE(AVG(o.total_amount), 0) as average_order_value,
                COUNT(DISTINCT o.user_id) as unique_customers
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
              AND o.status NOT IN ('cancelled')
              AND o.created_at BETWEEN $2 AND $3
        `;
        const totals = await db.query(totalsQuery, [req.user.id, startDate, endDate]);

        // Ventes par statut
        const byStatusQuery = `
            SELECT 
                o.status,
                COUNT(DISTINCT o.id) as count,
                COALESCE(SUM(oi.product_price * oi.quantity), 0) as revenue
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
              AND o.created_at BETWEEN $2 AND $3
            GROUP BY o.status
        `;
        const byStatus = await db.query(byStatusQuery, [req.user.id, startDate, endDate]);

        // Comparaison période précédente
        const periodDiff = endDate.getTime() - startDate.getTime();
        const prevStartDate = new Date(startDate.getTime() - periodDiff);
        const prevEndDate = startDate;

        const prevTotalsQuery = `
            SELECT 
                COUNT(DISTINCT o.id) as total_orders,
                COALESCE(SUM(oi.product_price * oi.quantity), 0) as total_revenue
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
              AND o.status NOT IN ('cancelled')
              AND o.created_at BETWEEN $2 AND $3
        `;
        const prevTotals = await db.query(prevTotalsQuery, [req.user.id, prevStartDate, prevEndDate]);

        const currentRevenue = parseFloat(totals.rows[0]?.total_revenue || 0);
        const prevRevenue = parseFloat(prevTotals.rows[0]?.total_revenue || 0);
        const revenueChange = prevRevenue > 0
            ? ((currentRevenue - prevRevenue) / prevRevenue * 100).toFixed(1)
            : null;

        res.json({
            period: { start: startDate, end: endDate },
            summary: {
                ...totals.rows[0],
                revenue_change_percent: revenueChange
            },
            chart_data: salesByDay.rows,
            by_status: byStatus.rows
        });
    } catch (error) {
        console.error('Error GET /reports/sales:', error);
        res.status(500).json({ error: 'Erreur génération rapport ventes' });
    }
});

/**
 * GET /reports/products - Rapport des produits
 */
router.get('/products', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '30d', sort = 'revenue', limit = 20 } = req.query;
        const { startDate, endDate } = getPeriodDates(period);

        // Top produits
        const topProductsQuery = `
            SELECT 
                p.id,
                p.name,
                p.images,
                p.price,
                p.quantity as stock,
                COALESCE(SUM(oi.quantity), 0) as units_sold,
                COALESCE(SUM(oi.product_price * oi.quantity), 0) as revenue,
                COUNT(DISTINCT o.id) as orders_count,
                p.created_at
            FROM products p
            LEFT JOIN order_items oi ON oi.product_id = p.id::text
            LEFT JOIN orders o ON o.id = oi.order_id 
                AND o.status NOT IN ('cancelled')
                AND o.created_at BETWEEN $2 AND $3
            WHERE p.seller_id = $1
            GROUP BY p.id
            ORDER BY ${sort === 'units' ? 'units_sold' : 'revenue'} DESC
            LIMIT $4
        `;
        const topProducts = await db.query(topProductsQuery, [req.user.id, startDate, endDate, parseInt(limit)]);

        // Produits sans ventes
        const noSalesQuery = `
            SELECT p.id, p.name, p.images, p.price, p.quantity as stock, p.created_at
            FROM products p
            WHERE p.seller_id = $1
              AND p.is_active = true
              AND NOT EXISTS (
                  SELECT 1 FROM order_items oi
                  JOIN orders o ON o.id = oi.order_id
                  WHERE oi.product_id = p.id::text
                    AND o.created_at >= $2
              )
            ORDER BY p.created_at DESC
            LIMIT 10
        `;
        const noSales = await db.query(noSalesQuery, [req.user.id, startDate]);

        // Statistiques globales
        const statsQuery = `
            SELECT 
                COUNT(*) as total_products,
                COUNT(*) FILTER (WHERE is_active = true) as active_products,
                COALESCE(SUM(quantity), 0) as total_stock,
                COUNT(*) FILTER (WHERE quantity < 5) as low_stock_count
            FROM products
            WHERE seller_id = $1
        `;
        const stats = await db.query(statsQuery, [req.user.id]);

        // Stock faible
        const lowStockQuery = `
            SELECT id, name, images, quantity as stock
            FROM products
            WHERE seller_id = $1 AND quantity < 5 AND is_active = true
            ORDER BY quantity ASC
            LIMIT 10
        `;
        const lowStock = await db.query(lowStockQuery, [req.user.id]);

        res.json({
            period: { start: startDate, end: endDate },
            stats: stats.rows[0],
            top_products: topProducts.rows.map(p => ({
                ...p,
                image: Array.isArray(p.images) ? p.images[0] : null
            })),
            no_sales: noSales.rows,
            low_stock: lowStock.rows
        });
    } catch (error) {
        console.error('Error GET /reports/products:', error);
        res.status(500).json({ error: 'Erreur génération rapport produits' });
    }
});

/**
 * GET /reports/customers - Rapport des clients
 */
router.get('/customers', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '30d', limit = 20 } = req.query;
        const { startDate, endDate } = getPeriodDates(period);

        // Top clients
        const topCustomersQuery = `
            SELECT 
                u.id,
                u.name,
                u.phone,
                COUNT(DISTINCT o.id) as orders_count,
                COALESCE(SUM(oi.product_price * oi.quantity), 0) as total_spent,
                MAX(o.created_at) as last_order,
                MIN(o.created_at) as first_order
            FROM users u
            JOIN orders o ON o.user_id = u.id
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
              AND o.status NOT IN ('cancelled')
              AND o.created_at BETWEEN $2 AND $3
            GROUP BY u.id
            ORDER BY total_spent DESC
            LIMIT $4
        `;
        const topCustomers = await db.query(topCustomersQuery, [req.user.id, startDate, endDate, parseInt(limit)]);

        // Stats clients
        const customerStatsQuery = `
            WITH customer_orders AS (
                SELECT 
                    u.id,
                    COUNT(DISTINCT o.id) as orders
                FROM users u
                JOIN orders o ON o.user_id = u.id
                JOIN order_items oi ON oi.order_id = o.id
                JOIN products p ON p.id::text = oi.product_id
                WHERE p.seller_id = $1
                  AND o.status NOT IN ('cancelled')
                  AND o.created_at BETWEEN $2 AND $3
                GROUP BY u.id
            )
            SELECT 
                COUNT(*) as total_customers,
                COUNT(*) FILTER (WHERE orders = 1) as one_time_buyers,
                COUNT(*) FILTER (WHERE orders > 1) as repeat_buyers,
                ROUND(AVG(orders)::numeric, 2) as avg_orders_per_customer
            FROM customer_orders
        `;
        const customerStats = await db.query(customerStatsQuery, [req.user.id, startDate, endDate]);

        // Nouveaux clients vs récurrents par jour
        const newVsReturningQuery = `
            WITH first_orders AS (
                SELECT u.id, MIN(o.created_at) as first_order_date
                FROM users u
                JOIN orders o ON o.user_id = u.id
                JOIN order_items oi ON oi.order_id = o.id
                JOIN products p ON p.id::text = oi.product_id
                WHERE p.seller_id = $1
                GROUP BY u.id
            )
            SELECT 
                DATE(o.created_at) as date,
                COUNT(DISTINCT o.user_id) FILTER (WHERE DATE(fo.first_order_date) = DATE(o.created_at)) as new_customers,
                COUNT(DISTINCT o.user_id) FILTER (WHERE DATE(fo.first_order_date) < DATE(o.created_at)) as returning_customers
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            JOIN first_orders fo ON fo.id = o.user_id
            WHERE p.seller_id = $1 AND o.created_at BETWEEN $2 AND $3
            GROUP BY DATE(o.created_at)
            ORDER BY date
        `;
        const newVsReturning = await db.query(newVsReturningQuery, [req.user.id, startDate, endDate]);

        res.json({
            period: { start: startDate, end: endDate },
            stats: customerStats.rows[0],
            top_customers: topCustomers.rows,
            new_vs_returning: newVsReturning.rows
        });
    } catch (error) {
        console.error('Error GET /reports/customers:', error);
        res.status(500).json({ error: 'Erreur génération rapport clients' });
    }
});

/**
 * GET /reports/export/pdf - Export PDF du rapport complet
 */
router.get('/export/pdf', requireAuth, requireSeller, async (req, res) => {
    try {
        const { period = '30d', type = 'sales' } = req.query;
        const { startDate, endDate } = getPeriodDates(period);

        // Récupérer les données selon le type
        let reportData = {};

        if (type === 'sales' || type === 'all') {
            const salesResult = await db.query(`
                SELECT 
                    COUNT(DISTINCT o.id) as total_orders,
                    COALESCE(SUM(oi.product_price * oi.quantity), 0) as total_revenue,
                    COALESCE(SUM(oi.quantity), 0) as total_items
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                JOIN products p ON p.id::text = oi.product_id
                WHERE p.seller_id = $1 AND o.status NOT IN ('cancelled')
                  AND o.created_at BETWEEN $2 AND $3
            `, [req.user.id, startDate, endDate]);
            reportData.sales = salesResult.rows[0];
        }

        if (type === 'products' || type === 'all') {
            const productsResult = await db.query(`
                SELECT p.name, COALESCE(SUM(oi.quantity), 0) as sold, 
                       COALESCE(SUM(oi.product_price * oi.quantity), 0) as revenue
                FROM products p
                LEFT JOIN order_items oi ON oi.product_id = p.id::text
                LEFT JOIN orders o ON o.id = oi.order_id AND o.created_at BETWEEN $2 AND $3
                WHERE p.seller_id = $1
                GROUP BY p.id
                ORDER BY revenue DESC
                LIMIT 10
            `, [req.user.id, startDate, endDate]);
            reportData.top_products = productsResult.rows;
        }

        // Générer HTML pour PDF (simple version, pas de dépendance externe)
        const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Rapport Vendeur - OLI</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 40px; color: #333; }
        h1 { color: #2563eb; border-bottom: 2px solid #2563eb; padding-bottom: 10px; }
        h2 { color: #1e40af; margin-top: 30px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .metric { background: #f3f4f6; padding: 20px; border-radius: 8px; text-align: center; flex: 1; }
        .metric-value { font-size: 28px; font-weight: bold; color: #2563eb; }
        .metric-label { color: #6b7280; font-size: 14px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
        th { background: #f9fafb; font-weight: 600; }
        .footer { margin-top: 40px; text-align: center; color: #9ca3af; font-size: 12px; }
    </style>
</head>
<body>
    <h1>📊 Rapport de Performance</h1>
    <p>Période: ${startDate.toLocaleDateString('fr-FR')} - ${endDate.toLocaleDateString('fr-FR')}</p>
    
    ${reportData.sales ? `
    <h2>Ventes</h2>
    <div class="summary">
        <div class="metric">
            <div class="metric-value">${reportData.sales.total_orders || 0}</div>
            <div class="metric-label">Commandes</div>
        </div>
        <div class="metric">
            <div class="metric-value">$${parseFloat(reportData.sales.total_revenue || 0).toFixed(2)}</div>
            <div class="metric-label">Chiffre d'affaires</div>
        </div>
        <div class="metric">
            <div class="metric-value">${reportData.sales.total_items || 0}</div>
            <div class="metric-label">Articles vendus</div>
        </div>
    </div>
    ` : ''}
    
    ${reportData.top_products ? `
    <h2>Top 10 Produits</h2>
    <table>
        <tr><th>Produit</th><th>Quantité vendue</th><th>Revenus</th></tr>
        ${reportData.top_products.map(p => `
            <tr>
                <td>${p.name}</td>
                <td>${p.sold}</td>
                <td>$${parseFloat(p.revenue || 0).toFixed(2)}</td>
            </tr>
        `).join('')}
    </table>
    ` : ''}
    
    <div class="footer">
        Généré par OLI Seller Center - ${new Date().toLocaleString('fr-FR')}
    </div>
</body>
</html>
        `;

        // Retourner le HTML (le client peut le convertir en PDF avec window.print())
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename=rapport_${type}_${period}.html`);
        res.send(html);
    } catch (error) {
        console.error('Error GET /reports/export/pdf:', error);
        res.status(500).json({ error: 'Erreur export PDF' });
    }
});

module.exports = router;
