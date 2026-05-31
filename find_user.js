require('dotenv').config();
const pool = require('./src/config/db');

async function findUser() {
    try {
        const res = await pool.query("SELECT id, name, wallet, phone FROM users WHERE name ILIKE '%OLI%' OR name = 'OLI USER'");
        console.log(res.rows);
    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}
findUser();
