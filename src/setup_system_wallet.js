const pool = require('./config/db');

async function setupSystemWallet() {
    try {
        await pool.query(`
            INSERT INTO users (id, name, email, phone, role, password, wallet)
            VALUES (0, 'OLI System Bank', 'bank@oli-core.com', '+0000000000', 'admin', 'N/A', 0)
            ON CONFLICT (id) DO NOTHING
        `);
        console.log('System user ensured');

        await pool.query(`
            INSERT INTO wallets (user_id, balance)
            VALUES (0, 0)
            ON CONFLICT (user_id) DO NOTHING
        `);
        console.log('System wallet ensured');
        process.exit(0);
    } catch(e) {
        console.error(e);
        process.exit(1);
    }
}
setupSystemWallet();
