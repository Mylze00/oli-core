require('dotenv').config();
const pool = require('./src/config/db');
pool.query('SELECT id, status, pickup_code, delivery_code FROM orders WHERE id IN (47,48,49,50) ORDER BY id')
    .then(r => {
        console.log(JSON.stringify(r.rows, null, 2));
        pool.end();
    })
    .catch(e => {
        console.error(e.message);
        pool.end();
    });
