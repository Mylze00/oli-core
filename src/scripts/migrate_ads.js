const pool = require('../config/db');

async function migrate() {
    try {
        console.log("🚀 Creating 'ads' table...");

        await pool.query(`
            CREATE TABLE IF NOT EXISTS ads (
                id SERIAL PRIMARY KEY,
                image_url TEXT NOT NULL,
                title VARCHAR(255),
                link_url TEXT,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        `);

        console.log("✅ Table 'ads' created successfully.");
        process.exit(0);
    } catch (err) {
        console.error("❌ Migration failed:", err);
        process.exit(1);
    }
}

migrate();
