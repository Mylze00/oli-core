require('dotenv').config();
const pool = require('./src/config/db');

async function checkMax() {
    try {
        const res = await pool.query('SELECT MAX(CAST(wallet AS NUMERIC)) FROM users');
        console.log('Max users wallet:', res.rows[0].max);

        const res2 = await pool.query('SELECT MAX(balance) FROM wallets');
        console.log('Max wallets balance:', res2.rows[0].max);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkMax();
