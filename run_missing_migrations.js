const pool = require('./src/config/db');
const fs = require('fs');
const path = require('path');

async function runMigrations() {
    try {
        console.log('Running 039...');
        const sql039 = fs.readFileSync(path.join(__dirname, 'src/migrations/039_oli_bank_crypto.sql'), 'utf8');
        await pool.query(sql039);
        console.log('✅ 039 executed!');

        console.log('Running 040...');
        const sql040 = fs.readFileSync(path.join(__dirname, 'src/migrations/040_wallets_and_transactions.sql'), 'utf8');
        await pool.query(sql040);
        console.log('✅ 040 executed!');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        await pool.end();
        process.exit(0);
    }
}

runMigrations();
