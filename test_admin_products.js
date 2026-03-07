const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool();

async function check() {
  try {
    const res = await pool.query(`
      SELECT COUNT(*) as total 
      FROM products p 
      JOIN users u ON p.seller_id = u.id
      WHERE u.phone = '+243827088682'
        AND p.status = 'active'
    `);
    console.log("Total ACTIVE admin products:", res.rows[0].total);

    const res2 = await pool.query(`
      SELECT COUNT(*) as total 
      FROM products p 
      WHERE p.status = 'active'
    `);
    console.log("Total ACTIVE products in DB:", res2.rows[0].total);
  } catch (err) {
    console.error(err);
  } finally {
    pool.end();
  }
}

check();
