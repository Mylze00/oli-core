const pool = require('../config/db');

async function migrate() {
    try {
        console.log("🚀 Starting migration: Add b2b_pricing column...");

        // Add b2b_pricing column if it doesn't exist
        await pool.query(`
            ALTER TABLE products 
            ADD COLUMN IF NOT EXISTS b2b_pricing JSONB DEFAULT '[]'::jsonb;
        `);

        console.log("✅ Column 'b2b_pricing' added successfully (or already exists).");
        process.exit(0);
    } catch (err) {
        console.error("❌ Migration failed:", err);
        process.exit(1);
    }
}

migrate();
