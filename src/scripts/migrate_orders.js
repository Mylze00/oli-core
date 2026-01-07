require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: false,
});

async function migrate() {
    const client = await pool.connect();
    try {
        console.log('🔌 Connecting to database...');

        // 1. Create Users Table
        console.log('📖 Reading Users SQL script...');
        const usersSqlPath = path.join(__dirname, 'create_users.sql');
        if (fs.existsSync(usersSqlPath)) {
            const usersSql = fs.readFileSync(usersSqlPath, 'utf8');
            console.log('🚀 Creating Users table...');
            await client.query(usersSql);
        } else {
            console.log('⚠️ create_users.sql not found!');
        }

        // 2. Create Orders Tables
        console.log('📖 Reading Orders SQL script...');
        const ordersSqlPath = path.join(__dirname, 'create_orders_tables.sql');
        if (fs.existsSync(ordersSqlPath)) {
            const ordersSql = fs.readFileSync(ordersSqlPath, 'utf8');
            console.log('🚀 Creating Orders tables...');
            await client.query(ordersSql);
        } else {
            console.log('⚠️ create_orders_tables.sql not found!');
        }

        console.log('✅ All migrations successful!');
    } catch (err) {
        console.error('❌ Migration failed:', err);
    } finally {
        client.release();
        await pool.end();
    }
}

migrate();
