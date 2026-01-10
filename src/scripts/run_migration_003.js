#!/usr/bin/env node

/**
 * Script d'exécution de la migration 003 - VERSION SIMPLIFIÉE
 * Correction de l'architecture des conversations
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });

const { Pool } = require('pg');
const fs = require('fs');

async function runMigration() {
    console.log('\n🚀 Démarrage de la migration 003...\n');

    // Configuration de la connexion
    const dbUrl = process.env.DATABASE_URL;

    if (!dbUrl) {
        console.error('❌ DATABASE_URL non trouvée dans le fichier .env');
        console.error('   Chemin .env attendu:', path.join(__dirname, '..', '..', '.env'));
        process.exit(1);
    }

    // Debug: afficher l'URL (masquer password)
    const urlMasked = dbUrl.replace(/:([^@:]+)@/, ':****@');
    console.log('🔍 Connexion à:', urlMasked, '\n');

    const pool = new Pool({
        connectionString: dbUrl,
        ssl: !dbUrl.includes('localhost') && !dbUrl.includes('127.0.0.1')
            ? { rejectUnauthorized: false }
            : false
    });

    // 1. Vérifier la connexion
    try {
        const result = await pool.query('SELECT NOW()');
        console.log('✅ Connexion établie à', result.rows[0].now, '\n');
    } catch (err) {
        console.error('❌ Erreur de connexion:', err.message);
        console.error('\n💡 Vérifiez que:');
        console.error('   1. PostgreSQL est démarré');
        console.error('   2. Les identifiants dans .env sont corrects');
        console.error('   3. La base de données "oli_db" existe\n');
        await pool.end();
        process.exit(1);
    }

    // 2. Afficher l'état actuel
    console.log('📊 État actuel:');
    try {
        const convCount = await pool.query('SELECT COUNT(*) FROM conversations');
        const partCount = await pool.query('SELECT COUNT(*) FROM conversation_participants');
        console.log(`   Conversations: ${convCount.rows[0].count}`);
        console.log(`   Participants: ${partCount.rows[0].count}\n`);
    } catch (err) {
        console.error('⚠️ ', err.message, '\n');
    }

    // 3. Confirmation
    const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
    });

    const confirmed = await new Promise(resolve => {
        readline.question('⚠️  Backup fait ? (oui/non): ', answer => {
            readline.close();
            resolve(answer.toLowerCase() === 'oui');
        });
    });

    if (!confirmed) {
        console.log('\n❌ Migration annulée. Faites un backup:\n');
        console.log('   pg_dump', dbUrl, '> backup.sql\n');
        await pool.end();
        process.exit(0);
    }

    // 4. Exécuter la migration
    const migrationPath = path.join(__dirname, '..', 'migrations', '003_fix_conversations_architecture.sql');

    if (!fs.existsSync(migrationPath)) {
        console.error(`❌ Fichier introuvable: ${migrationPath}`);
        await pool.end();
        process.exit(1);
    }

    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    console.log('\n🔄 Exécution...\n');

    try {
        await pool.query(migrationSQL);
        console.log('✅ Migration 003 réussie!\n');
    } catch (err) {
        console.error('❌ Erreur:', err.message);
        await pool.end();
        process.exit(1);
    }

    // 5. Vérifier le résultat
    console.log('📊 État final:');
    const convCount = await pool.query('SELECT COUNT(*) FROM conversations');
    const partCount = await pool.query('SELECT COUNT(*) FROM conversation_participants');
    console.log(`   Conversations: ${convCount.rows[0].count}`);
    console.log(`   Participants: ${partCount.rows[0].count}\n`);

    await pool.end();
    console.log('✨ Terminé!\n');
}

runMigration().catch(err => {
    console.error('💥 Erreur fatale:', err.message);
    process.exit(1);
});
