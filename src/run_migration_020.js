const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const pool = require('./config/db');

async function runMigration020() {
    const migrationPath = path.join(__dirname, 'migrations', '020_product_variants_and_import.sql');

    try {
        const sql = fs.readFileSync(migrationPath, 'utf8');
        console.log("🔄 Running migration: 020_product_variants_and_import.sql");
        console.log("Creating tables: import_history, product_variants, stock_alerts");

        await pool.query(sql);
        console.log("✅ Migration 020 successful!");

        // Vérifier que les tables sont créées
        const checkTables = await pool.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_name IN ('import_history', 'product_variants', 'stock_alerts')
        `);

        console.log("✅ Tables créées:", checkTables.rows.map(r => r.table_name).join(', '));

    } catch (err) {
        console.error("❌ Migration failed:", err.message);
        console.error("Stack:", err.stack);
    } finally {
        await pool.end();
    }
}

runMigration020();
