require('dotenv').config();
const pool = require('./src/config/db');

async function checkOrderId() {
    try {
        const res = await pool.query("SELECT unipesa_order_id, phone, provider FROM unipesa_operations WHERE oli_order_id = 'DEP-123-1780134283657'");
        console.log(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkOrderId();
