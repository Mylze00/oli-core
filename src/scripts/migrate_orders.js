const path = require('path');
const fs = require('fs');
const { Pool } = require('pg');

// Hardcoded for migration reliability
const CONNECTION_STRING = "postgresql://postgres:PIXELcongo243@localhost:5432/oli_db";

const pool = new Pool({
    connectionString: CONNECTION_STRING,
    ssl: false,
});

async function migrate() {
    console.log('🔌 Connecting to database...');
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

        // 3. Create Social Tables (Phase 2)
        console.log('📖 Reading Social SQL script...');
        const socialSqlPath = path.join(__dirname, 'create_social_tables.sql');
        if (fs.existsSync(socialSqlPath)) {
            const socialSql = fs.readFileSync(socialSqlPath, 'utf8');
            console.log('🚀 Creating Social tables (Products, Chat, Friends)...');
            await client.query(socialSql);
        } else {
            console.log('⚠️ create_social_tables.sql not found!');
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
