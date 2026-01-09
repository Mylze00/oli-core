const fs = require('fs');
const path = require('path');
const pool = require('./config/db');

async function runMigration() {
    const migrationPath = path.join(__dirname, 'migrations', 'add_reply_to_messages.sql');

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
