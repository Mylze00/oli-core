const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
// console.log("Checking Env:", process.env.DATABASE_URL ? "Loaded" : "Missing");
const pool = require('./config/db');

async function runMigration() {
    const migrationPath = path.join(__dirname, 'migrations', '017_add_express_delivery_price.sql');

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
