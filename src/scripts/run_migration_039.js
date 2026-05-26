/**
 * Script de migration 039 — OLI Bank Cryptographique
 * Usage: node src/scripts/run_migration_039.js
 */
const path = require('path');
const fs   = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });
const pool = require('../config/db');

async function run() {
    const sqlFile = path.join(__dirname, '../migrations/039_oli_bank_crypto.sql');
    const sql     = fs.readFileSync(sqlFile, 'utf8');

    console.log('🏦 OLI Bank — Exécution migration 039...');
    console.log('   Fichier:', sqlFile);

    try {
        await pool.query(sql);
        console.log('✅ Migration 039 réussie ! Tables OLI Bank créées.');
    } catch (err) {
        // Si les tables existent déjà (IF NOT EXISTS), ce n'est pas une erreur fatale
        if (err.message.includes('already exists')) {
            console.log('ℹ️  Tables déjà existantes (migration déjà appliquée).');
        } else {
            console.error('❌ Erreur migration:', err.message);
            process.exit(1);
        }
    } finally {
        await pool.end();
    }
}

run();
