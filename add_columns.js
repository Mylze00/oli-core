require('dotenv').config();
const pool = require('./src/config/db');
async function run() {
    await pool.query("ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'FC'");
    await pool.query("ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS order_id INTEGER REFERENCES orders(id) ON DELETE SET NULL");
    console.log('Columns added!');
    process.exit();
}
run();
