const pool = require('./src/config/db');
async function check() {
    const res = await pool.query('SELECT oli_order_id, status, unipesa_order_id, amount_fc, webhook_payload, error_message FROM unipesa_operations ORDER BY id DESC LIMIT 5');
    console.log(res.rows);
    process.exit();
}
check();
