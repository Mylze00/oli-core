require('dotenv').config();
const pool = require('./src/config/db');

async function run() {
  try {
    await pool.query(`
      ALTER TABLE wallet_transactions 
      ADD COLUMN IF NOT EXISTS label VARCHAR(255),
      ADD COLUMN IF NOT EXISTS counterpart_user_id INT,
      ADD COLUMN IF NOT EXISTS fee_amount DECIMAL(15,2);
    `);
    
    await pool.query(`
      ALTER TABLE unipesa_operations 
      ADD COLUMN IF NOT EXISTS wallet_tx_id INT REFERENCES wallet_transactions(id);
    `);
    
    console.log('Migration OK');
  } catch (e) {
    console.error('Migration failed', e);
  } finally {
    pool.end();
  }
}

run();
