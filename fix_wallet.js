require('dotenv').config();
const pool = require('./src/config/db');

async function fixWallet() {
    try {
        const phone = '+243978170364';
        
        // Trouver l'utilisateur
        const userRes = await pool.query('SELECT id, name FROM users WHERE phone = $1', [phone]);
        if (userRes.rows.length === 0) {
            console.log('Utilisateur non trouvé avec ce numéro.');
            process.exit();
        }
        const userId = userRes.rows[0].id;
        console.log(`Utilisateur trouvé: ${userRes.rows[0].name} (ID: ${userId})`);

        // Voir le solde actuel
        const walletRes = await pool.query('SELECT balance FROM wallets WHERE user_id = $1', [userId]);
        console.log(`Solde actuel: ${walletRes.rows[0].balance} FC`);

        // Voir les dernières transactions pour cet utilisateur
        const txRes = await pool.query('SELECT id, amount, type, reference, created_at FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5', [userId]);
        console.log('Dernières transactions:');
        console.table(txRes.rows);

    } catch(e) {
        console.error('Erreur:', e);
    }
    process.exit();
}

fixWallet();
