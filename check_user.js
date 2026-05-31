require('dotenv').config();
const pool = require('./src/config/db');

async function checkUser() {
    try {
        const res = await pool.query('SELECT wallet, phone, name FROM users WHERE phone = $1 OR phone = $2', ['+243978170364', '0978170364']);
        console.log(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
checkUser();
