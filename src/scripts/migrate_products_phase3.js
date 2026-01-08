const path = require('path');
const fs = require('fs');
const { Pool } = require('pg');

// Revert to environment variable for production
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes("render.com") ? { rejectUnauthorized: false } : false,
});

async function migrate() {
    console.log('🔌 Connecting to database...');
    const client = await pool.connect();
    try {
        console.log('📖 Reading Product Update SQL script (Phase 3)...');
        const sqlPath = path.join(__dirname, 'update_products_schema.sql');

        if (fs.existsSync(sqlPath)) {
            const sql = fs.readFileSync(sqlPath, 'utf8');
            console.log('🚀 Updating Products table schema...');
            await client.query(sql);
            console.log('✅ Update successful!');
        } else {
            console.log('⚠️ update_products_schema.sql not found!');
        }
    } catch (err) {
        console.error('❌ Migration failed:', err);
    } finally {
        client.release();
        await pool.end();
    }
}

migrate();
