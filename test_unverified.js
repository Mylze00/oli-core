require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
});

async function check() {
    try {
        const res = await pool.query(`SELECT COUNT(*) as total FROM products`);
        console.log('Total products:', res.rows[0].total);

        const unv = await pool.query(`SELECT COUNT(*) as unverified FROM products WHERE COALESCE(is_verified, FALSE) = FALSE AND status = 'active'`);
        console.log('Unverified active products:', unv.rows[0].unverified);

        const admin = await pool.query(`
      SELECT COUNT(*) as admin_prods 
      FROM products p 
      JOIN users u ON p.seller_id = u.id 
      WHERE u.phone = '+243827088682'
    `);
        console.log('Admin products:', admin.rows[0].admin_prods);

    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
}

check();
