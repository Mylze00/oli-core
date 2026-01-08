/**
 * Script pour exécuter les migrations SQL
 * Usage: node run_migration.js
 */
require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

async function runMigration() {
    const migrationFile = path.join(__dirname, 'migrations', 'add_product_id_to_conversations.sql');

    try {
        console.log('📦 Lecture du fichier de migration...');
        const sql = fs.readFileSync(migrationFile, 'utf8');

        console.log('🔄 Exécution de la migration...');
        console.log('SQL:', sql);

        await pool.query(sql);

        console.log('✅ Migration exécutée avec succès !');
    } catch (error) {
        console.error('❌ Erreur lors de la migration:', error.message);
    } finally {
        await pool.end();
    }
}

runMigration();
