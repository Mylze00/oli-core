require('dotenv').config();
const pool = require('./src/config/db');
async function run() {
    const res = await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name='wallet_transactions'");
    console.log(res.rows.map(r => r.column_name));
    process.exit();
}
run();
