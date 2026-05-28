require('dotenv').config();
const pool = require('./src/config/db');

async function fixDB() {
    try {
        await pool.query('ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS balance_before DECIMAL(15,2) DEFAULT 0, ADD COLUMN IF NOT EXISTS balance_after DECIMAL(15,2) DEFAULT 0;');
        console.log('Colonnes balance_before et balance_after ajoutées !');
    } catch (e) {
        console.error('Erreur SQL:', e.message);
    } finally {
        process.exit(0);
    }
}
fixDB();
