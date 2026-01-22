const pool = require('../config/db');

async function migrate() {
    try {
        console.log("🚀 Starting migration: Add unit/brand/weight columns...");

        await pool.query(`
            ALTER TABLE products 
            ADD COLUMN IF NOT EXISTS unit VARCHAR(50) DEFAULT 'Pièce',
            ADD COLUMN IF NOT EXISTS brand VARCHAR(100),
            ADD COLUMN IF NOT EXISTS weight VARCHAR(50);
        `);

        console.log("✅ Columns 'unit', 'brand', 'weight' added successfully.");
        process.exit(0);
    } catch (err) {
        console.error("❌ Migration failed:", err);
        process.exit(1);
    }
}

migrate();
