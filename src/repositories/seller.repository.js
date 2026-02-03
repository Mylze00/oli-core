/**
 * Seller Repository
 * Gestion des statistiques et données vendeur
 */

const db = require('../config/db');

/**
 * Récupère les statistiques du tableau de bord vendeur
 */
async function getSellerDashboard(sellerId) {
    try {
        // Convert to integer to avoid type mismatch errors
        const sellerIdInt = parseInt(sellerId);

        // Requête simplifiée sans GROUP BY problématique
        // Note: order_items.product_id est VARCHAR, products.id est INTEGER
        const query = `
            WITH seller_products AS (
                SELECT id, is_active 
                FROM products 
                WHERE seller_id = $1
            ),
            seller_orders AS (
                SELECT o.id, o.status, o.created_at, oi.quantity, oi.price
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                JOIN seller_products sp ON sp.id = CAST(oi.product_id AS INTEGER)
            )
            SELECT 
                -- Produits
                (SELECT COUNT(*) FROM seller_products) as total_products,
                (SELECT COUNT(*) FROM seller_products WHERE is_active = true) as active_products,
                
                -- Commandes du mois en cours
                (SELECT COUNT(DISTINCT id) FROM seller_orders 
                 WHERE created_at >= date_trunc('month', CURRENT_DATE)) as orders_this_month,
                
                -- Commandes en attente
                (SELECT COUNT(DISTINCT id) FROM seller_orders 
                 WHERE status IN ('pending', 'confirmed')) as pending_orders,
                
                -- Revenu du mois
                (SELECT COALESCE(SUM(quantity * price), 0) FROM seller_orders 
                 WHERE created_at >= date_trunc('month', CURRENT_DATE)) as revenue_this_month,
                
                -- Revenu total
                (SELECT COALESCE(SUM(quantity * price), 0) FROM seller_orders) as total_revenue,
                
                -- Nombre total de ventes
                (SELECT COALESCE(SUM(quantity), 0) FROM seller_orders) as total_sales
        `;

        const result = await db.query(query, [sellerIdInt]);

        // Toujours retourner des données, même si vides
        return result.rows[0] || {
            total_products: 0,
            active_products: 0,
            orders_this_month: 0,
            pending_orders: 0,
            revenue_this_month: 0,
            total_revenue: 0,
            total_sales: 0
        };
    } catch (error) {
        console.error('Error in getSellerDashboard:', error);
        // Retourner des données par défaut en cas d'erreur
        return {
            total_products: 0,
            active_products: 0,
            orders_this_month: 0,
            pending_orders: 0,
            revenue_this_month: 0,
            total_revenue: 0,
            total_sales: 0
        };
    }
}


/**
 * Récupère les données pour le graphique des ventes
 */
async function getSalesChart(sellerId, period = '7d') {
    try {
        const sellerIdInt = parseInt(sellerId);
        let interval, dateFormat;

        switch (period) {
            case '7d':
                interval = '7 days';
                dateFormat = 'YYYY-MM-DD';
                break;
            case '30d':
                interval = '30 days';
                dateFormat = 'YYYY-MM-DD';
                break;
            case '12m':
                interval = '12 months';
                dateFormat = 'YYYY-MM';
                break;
            default:
                interval = '7 days';
                dateFormat = 'YYYY-MM-DD';
        }

        const query = `
            SELECT 
                to_char(o.created_at, $3) as date,
                COUNT(DISTINCT o.id) as orders,
                COALESCE(SUM(oi.quantity * oi.price), 0) as revenue,
                COALESCE(SUM(oi.quantity), 0) as items_sold
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
            WHERE p.seller_id = $1
              AND o.created_at >= CURRENT_DATE - INTERVAL $2
            GROUP BY to_char(o.created_at, $3)
            ORDER BY date ASC
        `;

        const result = await db.query(query, [sellerIdInt, interval, dateFormat]);
        return result.rows;
    } catch (error) {
        console.error('Error in getSalesChart:', error);
        throw error;
    }
}

/**
 * Récupère les commandes du vendeur
 */
async function getSellerOrders(sellerId, status = null, limit = 50, offset = 0) {
    try {
        const sellerIdInt = parseInt(sellerId);
        let query = `
            SELECT DISTINCT
                o.id,
                o.user_id,
                o.status,
                o.total_amount,
                o.created_at,
                o.updated_at,
                u.name as customer_name,
                u.phone as customer_phone,
                COUNT(oi.id) as items_count
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
            LEFT JOIN users u ON u.id = o.user_id
            WHERE p.seller_id = $1
        `;

        const params = [sellerIdInt];

        if (status) {
            query += ` AND o.status = $${params.length + 1}`;
            params.push(status);
        }

        query += `
            GROUP BY o.id, u.name, u.phone
            ORDER BY o.created_at DESC
            LIMIT $${params.length + 1} OFFSET $${params.length + 2}
        `;

        params.push(limit, offset);

        const result = await db.query(query, params);
        return result.rows;
    } catch (error) {
        console.error('Error in getSellerOrders:', error);
        throw error;
    }
}

/**
 * Récupère les détails d'une commande pour un vendeur
 */
async function getSellerOrderDetails(sellerId, orderId) {
    try {
        const sellerIdInt = parseInt(sellerId);
        const query = `
            SELECT 
                o.*,
                u.name as customer_name,
                u.phone as customer_phone,
                u.avatar_url as customer_avatar,
                json_agg(
                    json_build_object(
                        'id', oi.id,
                        'product_id', p.id,
                        'product_name', p.name,
                        'product_image', p.image_url,
                        'quantity', oi.quantity,
                        'price', oi.price,
                        'subtotal', oi.quantity * oi.price
                    )
                ) as items
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
            LEFT JOIN users u ON u.id = o.user_id
            WHERE o.id = $1
              AND p.seller_id = $2
            GROUP BY o.id, u.name, u.phone, u.avatar_url
        `;

        const result = await db.query(query, [orderId, sellerIdInt]);
        return result.rows[0] || null;
    } catch (error) {
        console.error('Error in getSellerOrderDetails:', error);
        throw error;
    }
}

/**
 * Récupère les analytics avancés du vendeur
 * KPIs: taux de conversion, panier moyen, vues totales
 */
async function getAdvancedAnalytics(sellerId) {
    try {
        const sellerIdInt = parseInt(sellerId);
        
        const query = `
            WITH seller_products AS (
                SELECT id, COALESCE(view_count, 0) as views
                FROM products 
                WHERE seller_id = $1
            ),
            seller_orders AS (
                SELECT DISTINCT o.id, o.total_amount
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                JOIN seller_products sp ON sp.id = CAST(oi.product_id AS INTEGER)
                WHERE o.status NOT IN ('cancelled', 'refunded')
            )
            SELECT 
                -- Total vues
                COALESCE((SELECT SUM(views) FROM seller_products), 0)::integer as total_views,
                
                -- Panier moyen
                COALESCE((SELECT AVG(total_amount) FROM seller_orders), 0)::numeric(10,2) as average_cart,
                
                -- Nombre de commandes (pour calcul conversion)
                (SELECT COUNT(*) FROM seller_orders)::integer as completed_orders,
                
                -- Taux de conversion approximatif (commandes / vues * 100)
                CASE 
                    WHEN (SELECT SUM(views) FROM seller_products) > 0 
                    THEN ROUND(
                        (SELECT COUNT(*) FROM seller_orders)::numeric 
                        / NULLIF((SELECT SUM(views) FROM seller_products), 0) * 100, 2
                    )
                    ELSE 0 
                END as conversion_rate
        `;
        
        const result = await db.query(query, [sellerIdInt]);
        return result.rows[0] || {
            total_views: 0,
            average_cart: 0,
            completed_orders: 0,
            conversion_rate: 0
        };
    } catch (error) {
        console.error('Error in getAdvancedAnalytics:', error);
        return {
            total_views: 0,
            average_cart: 0,
            completed_orders: 0,
            conversion_rate: 0
        };
    }
}

/**
 * Récupère les Top N produits les plus vendus
 */
async function getTopProducts(sellerId, limit = 10) {
    try {
        const sellerIdInt = parseInt(sellerId);
        
        const query = `
            SELECT 
                p.id,
                p.name,
                p.images,
                p.price,
                COALESCE(p.view_count, 0) as views,
                COALESCE(SUM(oi.quantity), 0)::integer as units_sold,
                COALESCE(SUM(oi.quantity * oi.price), 0)::numeric(10,2) as revenue
            FROM products p
            LEFT JOIN order_items oi ON CAST(oi.product_id AS INTEGER) = p.id
            LEFT JOIN orders o ON o.id = oi.order_id AND o.status NOT IN ('cancelled', 'refunded')
            WHERE p.seller_id = $1 AND p.is_active = true
            GROUP BY p.id, p.name, p.images, p.price, p.view_count
            ORDER BY units_sold DESC, revenue DESC
            LIMIT $2
        `;
        
        const result = await db.query(query, [sellerIdInt, limit]);
        return result.rows;
    } catch (error) {
        console.error('Error in getTopProducts:', error);
        return [];
    }
}

/**
 * Récupère les produits sans ventes récentes (à optimiser)
 */
async function getProductsWithoutSales(sellerId, days = 30) {
    try {
        const sellerIdInt = parseInt(sellerId);
        
        const query = `
            SELECT 
                p.id,
                p.name,
                p.images,
                p.price,
                p.created_at,
                COALESCE(p.view_count, 0) as views
            FROM products p
            WHERE p.seller_id = $1
              AND p.is_active = true
              AND NOT EXISTS (
                SELECT 1 FROM order_items oi
                JOIN orders o ON o.id = oi.order_id
                WHERE CAST(oi.product_id AS INTEGER) = p.id
                  AND o.created_at >= CURRENT_DATE - INTERVAL '1 day' * $2
                  AND o.status NOT IN ('cancelled', 'refunded')
              )
            ORDER BY p.view_count DESC, p.created_at DESC
            LIMIT 10
        `;
        
        const result = await db.query(query, [sellerIdInt, days]);
        return result.rows;
    } catch (error) {
        console.error('Error in getProductsWithoutSales:', error);
        return [];
    }
}

/**
 * Récupère les dernières commandes du vendeur (widget dashboard)
 */
async function getRecentOrders(sellerId, limit = 5) {
    try {
        const sellerIdInt = parseInt(sellerId);
        
        const query = `
            SELECT DISTINCT
                o.id,
                o.status,
                o.total_amount,
                o.created_at,
                u.name as customer_name,
                (SELECT COUNT(*) FROM order_items oi2 
                 JOIN products p2 ON p2.id = CAST(oi2.product_id AS INTEGER)
                 WHERE oi2.order_id = o.id AND p2.seller_id = $1
                ) as items_count
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
            LEFT JOIN users u ON u.id = o.user_id
            WHERE p.seller_id = $1
            ORDER BY o.created_at DESC
            LIMIT $2
        `;
        
        const result = await db.query(query, [sellerIdInt, limit]);
        return result.rows;
    } catch (error) {
        console.error('Error in getRecentOrders:', error);
        return [];
    }
}

module.exports = {
    getSellerDashboard,
    getSalesChart,
    getSellerOrders,
    getSellerOrderDetails,
    // 🆕 Analytics avancés
    getAdvancedAnalytics,
    getTopProducts,
    getProductsWithoutSales,
    getRecentOrders
};
