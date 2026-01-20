const pool = require('../config/db');

class WalletRepository {
    async getBalance(userId) {
        const res = await pool.query("SELECT wallet FROM users WHERE id = $1", [userId]);
        return parseFloat(res.rows[0]?.wallet || 0);
    }

    async getHistory(userId, limit = 20) {
        const res = await pool.query(
            "SELECT * FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2",
            [userId, limit]
        );
        return res.rows;
    }

    async performDeposit(userId, amount, provider, reference, description) {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            const txRes = await client.query(`
                INSERT INTO wallet_transactions 
                (user_id, type, amount, balance_after, provider, reference, status, description)
                VALUES ($1, 'deposit', $2, 
                    (SELECT COALESCE(wallet, 0) + $2 FROM users WHERE id = $1), 
                    $3, $4, $5, $6)
                RETURNING id, balance_after
            `, [userId, amount, provider, reference, 'completed', description]);

            const newBalance = txRes.rows[0].balance_after;

            await client.query("UPDATE users SET wallet = $1 WHERE id = $2", [newBalance, userId]);

            await client.query('COMMIT');

            return {
                id: txRes.rows[0].id,
                balanceAfter: newBalance
            };
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    async performWithdrawal(userId, amount, provider, reference, description) {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // 1. Lock user row & check balance
            const userRes = await client.query("SELECT wallet FROM users WHERE id = $1 FOR UPDATE", [userId]);
            const currentBalance = parseFloat(userRes.rows[0].wallet || 0);

            if (currentBalance < amount) {
                throw new Error("Solde insuffisant");
            }

            const newBalance = currentBalance - amount;

            const txRes = await client.query(`
                INSERT INTO wallet_transactions 
                (user_id, type, amount, balance_after, provider, reference, status, description)
                VALUES ($1, 'withdrawal', $2, $3, $4, $5, 'completed', $6)
                RETURNING id
            `, [userId, -amount, newBalance, provider, reference, description]);

            await client.query("UPDATE users SET wallet = $1 WHERE id = $2", [newBalance, userId]);

            await client.query('COMMIT');

            return {
                id: txRes.rows[0].id,
                balanceAfter: newBalance
            };

        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }
}

module.exports = new WalletRepository();
