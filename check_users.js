const pool = require('./src/config/db');

async function check() {
    try {
        const res = await pool.query('SELECT column_name FROM information_schema.columns WHERE table_name = \'users\'');
        console.log(res.rows.map(r => r.column_name));
    } catch (err) {
        console.error('Error:', err);
    } finally {
        await pool.end();
        process.exit(0);
    }
}

check();
