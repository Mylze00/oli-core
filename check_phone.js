require('dotenv').config();
const pool = require('./src/config/db');

async function checkPhone() {
    try {
        const res = await pool.query('SELECT phone FROM unipesa_operations ORDER BY initiated_at DESC LIMIT 2');
        console.log(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkPhone();
