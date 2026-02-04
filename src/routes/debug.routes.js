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
