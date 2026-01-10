const pool = require('../config/db');
const mmService = require('./mobile-money.service');

class WalletService {

    /**
     * Obtenir le solde actuel d'un utilisateur
     */
    async getBalance(userId) {
        // En phase 1, le solde peut être stocké dans `users.wallet` ou calculé.
        // Pour la robustesse, on lit `users.wallet` qui est mis à jour par trigger ou transaction.
        // Ici, on va lire la colonne `wallet` (ou `balance` selon le schema actuel, vérifions `users`).
        // Le rapport d'audit dit `users.wallet` type numeric.

        const res = await pool.query("SELECT wallet FROM users WHERE id = $1", [userId]);
        return parseFloat(res.rows[0]?.wallet || 0);
    }

    /**
     * Dépôt via Mobile Money
     */
    async deposit(userId, amount, provider, phoneNumber) {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // 1. Appel API Mobile Money simule
            const mmRes = await mmService.initiatePayment(provider, phoneNumber, amount);

            if (!mmRes.success || mmRes.status === 'failed') {
                throw new Error(mmRes.message || "Échec du paiement Mobile Money");
            }

            // 2. Si succès, enregistrer transaction
            const txRes = await client.query(`
                INSERT INTO wallet_transactions 
                (user_id, type, amount, balance_after, provider, reference, status, description)
                VALUES ($1, 'deposit', $2, 
                    (SELECT COALESCE(wallet, 0) + $2 FROM users WHERE id = $1), 
                    $3, $4, $5, $6)
                RETURNING id, balance_after
            `, [userId, amount, provider, mmRes.transaction_id, mmRes.status, `Dépôt via ${provider}`]);

            const newBalance = txRes.rows[0].balance_after;

            // 3. Mettre à jour solde user
            await client.query("UPDATE users SET wallet = $1 WHERE id = $2", [newBalance, userId]);

            await client.query('COMMIT');

            return {
                success: true,
                newBalance,
                transactionId: txRes.rows[0].id,
                mmResult: mmRes
            };

        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    /**
     * Retrait vers Mobile Money
     */
    async withdraw(userId, amount, provider, phoneNumber) {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // 1. Vérifier solde
            const userRes = await client.query("SELECT wallet FROM users WHERE id = $1 FOR UPDATE", [userId]);
            const currentBalance = parseFloat(userRes.rows[0].wallet || 0);

            if (currentBalance < amount) {
                throw new Error("Solde insuffisant");
            }

            // 2. Appel API Mobile Money
            const mmRes = await mmService.sendMoney(provider, phoneNumber, amount);

            // 3. Enregistrer transaction (débit)
            const newBalance = currentBalance - amount;

            const txRes = await client.query(`
                INSERT INTO wallet_transactions 
                (user_id, type, amount, balance_after, provider, reference, status, description)
                VALUES ($1, 'withdrawal', $2, $3, $4, $5, 'completed', $6)
                RETURNING id
            `, [userId, -amount, newBalance, provider, mmRes.transaction_id, `Retrait vers ${provider}`]);

            // 4. Mettre à jour User
            await client.query("UPDATE users SET wallet = $1 WHERE id = $2", [newBalance, userId]);

            await client.query('COMMIT');

            return {
                success: true,
                newBalance,
                transactionId: txRes.rows[0].id
            };

        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    /**
     * Paiement interne (Achat produit) // Sera utilisé quand on fera les commandes
     */
    async processPayment(buyerId, amount, description) {
        // ... logique similaire avec transfert interne ...
        // Implementation future
    }

    /**
     * Historique transactions
     */
    async getHistory(userId, limit = 20) {
        const res = await pool.query(
            "SELECT * FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2",
            [userId, limit]
        );
        return res.rows;
    }
}

module.exports = new WalletService();
