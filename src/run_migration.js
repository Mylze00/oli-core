const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
// console.log("Checking Env:", process.env.DATABASE_URL ? "Loaded" : "Missing");
const pool = require('./config/db');

async function runMigration() {
    const arg = process.argv[2];
    if (!arg) {
        console.error("❌ Usage: node src/run_migration.js <migration_file>");
        console.error("   Example: node src/run_migration.js src/migrations/021_order_workflow.sql");
        process.exit(1);
    }
    const migrationPath = path.resolve(arg);

    try {
        const sql = fs.readFileSync(migrationPath, 'utf8');
        console.log("Running migration:", migrationPath);

        await pool.query(sql);
        console.log("✅ Migration successful!");
    } catch (err) {
        console.error("❌ Migration failed:", err.message);
    } finally {
        await pool.end();
    }
}

runMigration();
