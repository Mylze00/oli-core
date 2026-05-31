require('dotenv').config();
const pool = require('./src/config/db');

async function checkAmount() {
    try {
        const res = await pool.query('SELECT oli_order_id, amount_fc, status, error_message FROM unipesa_operations ORDER BY initiated_at DESC LIMIT 5');
        console.table(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkAmount();
