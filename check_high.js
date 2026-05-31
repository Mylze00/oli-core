require('dotenv').config();
const pool = require('./src/config/db');

async function checkHigh() {
    try {
        const res = await pool.query('SELECT user_id, balance FROM wallets WHERE balance > 2000000');
        console.log(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkHigh();
