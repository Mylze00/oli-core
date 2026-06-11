require('dotenv').config();
const pool = require('/home/paolice-mylze/oli-core/src/config/db');

async function migrate() {
    const client = await pool.connect();
    try {
        console.log('Starting Oticket DB Migration...');
        await client.query('BEGIN');

        // 1. Ajout de la référence de passerelle à la table orders existante
        await client.query(`
            ALTER TABLE orders 
            ADD COLUMN IF NOT EXISTS gateway_transaction_id VARCHAR(255);
        `);
        console.log('✅ orders updated');

        // 2. Ajout de la ventilation financière pour les tickets dans order_items
        await client.query(`
            ALTER TABLE order_items 
            ADD COLUMN IF NOT EXISTS base_price NUMERIC(10, 2) DEFAULT 0,
            ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10, 2) DEFAULT 0,
            ADD COLUMN IF NOT EXISTS final_price NUMERIC(10, 2) DEFAULT 0;
        `);
        console.log('✅ order_items updated');

        // 3. Création de la table organizer_balances
        await client.query(`
            CREATE TABLE IF NOT EXISTS organizer_balances (
                organizer_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                available_balance NUMERIC(12, 2) DEFAULT 0.00,
                pending_balance NUMERIC(12, 2) DEFAULT 0.00,
                total_earned NUMERIC(12, 2) DEFAULT 0.00,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ organizer_balances created');

        // Index pour accélérer les recherches sur la passerelle
        await client.query(`
            CREATE INDEX IF NOT EXISTS idx_orders_gateway_tx ON orders(gateway_transaction_id);
        `);
        console.log('✅ Indexes created');

        await client.query('COMMIT');
        console.log('🚀 Migration successful!');
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('❌ Migration failed:', e);
    } finally {
        client.release();
        process.exit(0);
    }
}

migrate();
