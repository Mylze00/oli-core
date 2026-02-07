/**
 * Script de diagnostic de la base de données OLI
 * À exécuter dans le Shell Render: node scripts/check_db.js
 */

require('dotenv').config();
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;

console.log('='.repeat(60));
console.log('🔍 DIAGNOSTIC BASE DE DONNÉES OLI');
console.log('='.repeat(60));

// 1. Vérifier la variable DATABASE_URL
console.log('\n📋 1. Variable DATABASE_URL:');
if (!DATABASE_URL) {
    console.log('   ❌ DATABASE_URL non définie !');
    process.exit(1);
}

// Masquer le mot de passe dans les logs
const maskedUrl = DATABASE_URL.replace(/:([^@]+)@/, ':****@');
console.log(`   URL: ${maskedUrl}`);

// Extraire le hostname
const match = DATABASE_URL.match(/@([^:\/]+)/);
const hostname = match ? match[1] : 'inconnu';
console.log(`   Hostname: ${hostname}`);

// 2. Tester la connexion
async function runDiagnostic() {
    console.log('\n📋 2. Test de connexion...');

    const pool = new Pool({
        connectionString: DATABASE_URL,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 10000,
    });

    try {
        const client = await pool.connect();
        console.log('   ✅ Connexion réussie !');

        // 3. Version PostgreSQL
        const versionResult = await client.query('SELECT version()');
        console.log(`\n📋 3. ${versionResult.rows[0].version.split(',')[0]}`);

        // 4. Lister toutes les tables existantes
        console.log('\n📋 4. Tables existantes:');
        const tablesResult = await client.query(`
      SELECT table_name, 
             pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size,
             (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name) as columns
      FROM information_schema.tables t
      WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);

        const existingTables = tablesResult.rows.map(r => r.table_name);

        tablesResult.rows.forEach((row, i) => {
            console.log(`   ${(i + 1).toString().padStart(2)}. ${row.table_name.padEnd(30)} | ${row.columns} cols | ${row.size}`);
        });
        console.log(`\n   Total: ${existingTables.length} tables`);

        // 5. Vérifier les tables attendues
        const expectedTables = [
            'users', 'products', 'orders', 'order_items',
            'conversations', 'conversation_participants', 'messages',
            'friendships', 'payment_methods',
            'shops', 'product_variants', 'stock_alerts', 'import_history',
            'services', 'service_requests',
            'addresses', 'user_product_views', 'user_identity_documents',
            'user_verification_levels', 'user_behavior_events',
            'user_sessions', 'user_trust_scores', 'user_avatar_history',
            'transactions', 'wallet_transactions', 'exchange_rates',
            'coupons', 'coupon_usages', 'loyalty_points',
            'loyalty_transactions', 'loyalty_settings',
            'order_status_history', 'seller_notifications',
            'delivery_orders', 'deliveries',
            'ads', 'notifications', 'favorites', 'disputes',
            'support_tickets', 'support_messages',
        ];

        console.log('\n📋 5. Tables manquantes:');
        const missing = expectedTables.filter(t => !existingTables.includes(t));
        const extra = existingTables.filter(t => !expectedTables.includes(t));

        if (missing.length === 0) {
            console.log('   ✅ Aucune table manquante !');
        } else {
            missing.forEach(t => console.log(`   ❌ ${t}`));
            console.log(`\n   Total manquantes: ${missing.length}/${expectedTables.length}`);
        }

        if (extra.length > 0) {
            console.log('\n📋 6. Tables supplémentaires (non attendues):');
            extra.forEach(t => console.log(`   ⚪ ${t}`));
        }

        // 7. Comptage des lignes pour les tables critiques
        console.log('\n📋 7. Données dans les tables critiques:');
        const criticalTables = ['users', 'products', 'orders', 'order_items', 'shops', 'conversations', 'messages'];

        for (const table of criticalTables) {
            if (existingTables.includes(table)) {
                try {
                    const countResult = await client.query(`SELECT COUNT(*) FROM ${table}`);
                    console.log(`   ${table.padEnd(25)} → ${countResult.rows[0].count} lignes`);
                } catch (e) {
                    console.log(`   ${table.padEnd(25)} → ❌ Erreur: ${e.message}`);
                }
            } else {
                console.log(`   ${table.padEnd(25)} → ⚠️  TABLE ABSENTE`);
            }
        }

        client.release();
        await pool.end();

        console.log('\n' + '='.repeat(60));
        if (missing.length === 0) {
            console.log('✅ DIAGNOSTIC OK - Toutes les tables sont présentes');
        } else {
            console.log(`⚠️  ${missing.length} table(s) manquante(s) à créer`);
        }
        console.log('='.repeat(60));

    } catch (error) {
        console.log(`   ❌ Connexion échouée: ${error.message}`);

        if (error.code === 'ENOTFOUND') {
            console.log('\n🔴 DIAGNOSTIC: Le hostname de la base de données est introuvable.');
            console.log('   → La base de données a probablement expiré ou été supprimée.');
            console.log('   → Allez sur dashboard.render.com > PostgreSQL pour vérifier.');
            console.log('   → Si supprimée, créez-en une nouvelle et mettez à jour DATABASE_URL.');
        } else if (error.code === 'ECONNREFUSED') {
            console.log('\n🔴 DIAGNOSTIC: Connexion refusée par le serveur.');
            console.log('   → La base existe mais refuse les connexions.');
        } else if (error.message.includes('authentication')) {
            console.log('\n🔴 DIAGNOSTIC: Erreur d\'authentification.');
            console.log('   → Vérifiez le user/password dans DATABASE_URL.');
        }

        await pool.end();
        process.exit(1);
    }
}

runDiagnostic();
