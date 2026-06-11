const pool = require('./src/config/db');
const fs = require('fs');

const sql = fs.readFileSync('./migrations/create_call_logs_table.sql', 'utf8');

pool.query(sql)
  .then(() => {
    console.log('Table created');
    process.exit(0);
  })
  .catch(e => {
    console.error('Error creating table:', e);
    process.exit(1);
  });
