const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// Route de debug pour vérifier la structure de la base de données
router.get('/db-schema', async (req, res) => {
    try {
        const client = await pool.connect();
        try {
            // Check tables
            const tablesRes = await client.query(`
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
            `);
            const tables = tablesRes.rows.map(r => r.table_name);

            // Check users columns
            const usersColsRes = await client.query(`
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'users'
            `);
            const usersCols = usersColsRes.rows.map(r => r.column_name);

            // Check if import_history exists
            const historyExists = tables.includes('import_history');

            res.json({
                success: true,
                environment: process.env.NODE_ENV,
                db_host: process.env.DB_HOST || 'unknown',
                tables,
                users_columns: usersCols,
                is_seller_column_exists: usersCols.includes('is_seller'),
                import_history_table_exists: historyExists
            });

        } finally {
            client.release();
        }
    } catch (err) {
        res.status(500).json({ error: err.message, stack: err.stack });
    }
});

module.exports = router;

// Debug: check order + delivery status
router.get('/order-status/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const order = await pool.query('SELECT id, status, payment_status, payment_method, total_amount, delivery_address, created_at FROM orders WHERE id = $1', [id]);
        const delivery = await pool.query('SELECT * FROM delivery_orders WHERE order_id = $1', [id]);
        const allDeliveries = await pool.query('SELECT id, order_id, status, created_at FROM delivery_orders ORDER BY created_at DESC LIMIT 10');
        const allOrders = await pool.query('SELECT id, status, payment_status, payment_method, total_amount FROM orders ORDER BY id DESC LIMIT 10');
        res.json({
            order: order.rows[0] || null,
            delivery_order: delivery.rows[0] || null,
            recent_orders: allOrders.rows,
            recent_deliveries: allDeliveries.rows,
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});
