/**
 * run_migration_040.js
 * Exécute la migration 040 (wallets + wallet_transactions + unipesa_operations)
 * sur la base de données de production.
 *
 * Usage (depuis ~/oli-core sur Ubuntu/WSL) :
 *   NODE_OPTIONS="--dns-result-order=ipv4first" node run_migration_040.js
 */

require('dotenv').config();
const { Pool } = require('pg');
const fs       = require('fs');
const path     = require('path');

async function runMigration() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false },
    });

    console.log('🐘 Connexion à la base de données...');

    const sqlPath = path.join(__dirname, 'src/migrations/040_wallets_and_transactions.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    try {
        console.log('⚙️  Exécution de la migration 040...');
        await pool.query(sql);
        console.log('✅ Migration 040 exécutée avec succès !');
        console.log('   Tables créées : wallets, wallet_transactions, unipesa_operations');

        // Vérification
        const check = await pool.query(`
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name IN ('wallets', 'wallet_transactions', 'unipesa_operations')
            ORDER BY table_name
        `);
        console.log('\n📋 Tables vérifiées en base :');
        check.rows.forEach(r => console.log(`   ✓ ${r.table_name}`));

        // Compter les wallets créés
        const count = await pool.query('SELECT COUNT(*) FROM wallets');
        console.log(`\n👛 Wallets initialisés : ${count.rows[0].count}`);

    } catch (err) {
        console.error('❌ Erreur lors de la migration :', err.message);
        process.exit(1);
    } finally {
        await pool.end();
        process.exit(0);
    }
}

runMigration();
