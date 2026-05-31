require('dotenv').config();
const pool = require('./src/config/db');

async function syncWallets() {
    try {
        console.log('=== Audit wallets désynchronisés ===\n');

        // Lister tous les utilisateurs où users.wallet != wallets.balance
        const res = await pool.query(`
            SELECT 
                u.id,
                u.phone,
                u.name,
                CAST(u.wallet AS DECIMAL) as users_wallet,
                w.balance as wallets_balance,
                ABS(CAST(u.wallet AS DECIMAL) - w.balance) as diff
            FROM users u
            JOIN wallets w ON w.user_id = u.id
            WHERE ABS(CAST(u.wallet AS DECIMAL) - w.balance) > 1
            ORDER BY diff DESC
        `);

        if (res.rows.length === 0) {
            console.log('✅ Tous les wallets sont synchronisés !');
        } else {
            console.log(`⚠️  ${res.rows.length} wallet(s) désynchronisé(s) :\n`);
            console.table(res.rows.map(r => ({
                'ID': r.id,
                'Téléphone': r.phone,
                'Nom': r.name || '(sans nom)',
                'users.wallet': parseFloat(r.users_wallet).toLocaleString('fr-CD') + ' FC',
                'wallets.balance': parseFloat(r.wallets_balance).toLocaleString('fr-CD') + ' FC',
                'Différence': parseFloat(r.diff).toLocaleString('fr-CD') + ' FC',
            })));

            // Corriger : mettre à jour users.wallet pour correspondre à wallets.balance
            console.log('\n🔧 Correction en cours...');
            const fix = await pool.query(`
                UPDATE users u
                SET wallet = w.balance::TEXT, updated_at = NOW()
                FROM wallets w
                WHERE w.user_id = u.id
                  AND ABS(CAST(u.wallet AS DECIMAL) - w.balance) > 1
                RETURNING u.id, u.phone, w.balance as new_balance
            `);
            console.log(`✅ ${fix.rows.length} wallet(s) corrigé(s) :`);
            fix.rows.forEach(r => {
                console.log(`  User #${r.id} (${r.phone}) → ${parseFloat(r.new_balance).toLocaleString('fr-CD')} FC`);
            });
        }
    } catch (e) {
        console.error('Erreur:', e);
    }
    process.exit();
}

syncWallets();
