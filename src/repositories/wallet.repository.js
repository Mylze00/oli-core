/**
 * Wallet Repository — Toutes les opérations atomiques sur le wallet OLI
 *
 * Design:
 *  - Chaque opération s'exécute dans une transaction PostgreSQL
 *  - SELECT FOR UPDATE sur wallets pour éviter les race conditions
 *  - Jamais de mise à jour partielle (BEGIN/COMMIT/ROLLBACK)
 *  - Tous les montants passent par parseFloat() avant d'entrer
 */
const pool = require('../config/db');

class WalletRepository {

    // ─────────────────────────────────────────────────────────────
    // Helpers internes
    // ─────────────────────────────────────────────────────────────

    /**
     * Récupère ou crée le wallet d'un utilisateur (idempotent).
     * Retourne le row wallet avec le lock FOR UPDATE si `client` fourni.
     */
    async _getOrCreateWallet(userIdRaw, client = null) {
        const userId = parseInt(userIdRaw);
        const db = client || pool;

        // Créer si inexistant
        await db.query(
            `INSERT INTO wallets (user_id, balance) VALUES ($1, 0.00) ON CONFLICT (user_id) DO NOTHING`,
            [userId]
        );

        const lockClause = client ? 'FOR UPDATE' : '';
        const res = await db.query(
            `SELECT * FROM wallets WHERE user_id = $1 ${lockClause}`,
            [userId]
        );

        if (!res.rows[0]) throw new Error(`Wallet introuvable pour user #${userId}`);
        return res.rows[0];
    }

    /**
     * Insère une ligne dans wallet_transactions et retourne l'entrée créée.
     */
    async _insertTx(client, { walletId, userId, type, amount, balanceAfter, provider, reference, description, orderId, metadata }) {
        const res = await client.query(`
            INSERT INTO wallet_transactions
                (wallet_id, user_id, type, amount, balance_after, provider, reference,
                 description, order_id, metadata, status, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'completed', NOW())
            RETURNING *
        `, [
            walletId,
            parseInt(userId),
            type,
            amount,
            balanceAfter,
            provider || null,
            reference || null,
            description || null,
            orderId || null,
            metadata ? JSON.stringify(metadata) : null,
        ]);
        return res.rows[0];
    }

    // ─────────────────────────────────────────────────────────────
    // API publique
    // ─────────────────────────────────────────────────────────────

    /**
     * Retourne le solde actuel de l'utilisateur (en USD).
     */
    async getBalance(userId) {
        const wallet = await this._getOrCreateWallet(userId);
        return parseFloat(wallet.balance);
    }

    /**
     * Retourne l'historique des transactions (limité à `limit`).
     */
    async getHistory(userId, limit = 30) {
        const userIdInt = parseInt(userId);
        const res = await pool.query(`
            SELECT  t.id, t.type, t.amount, t.balance_after, t.provider,
                    t.reference, t.description, t.order_id, t.metadata,
                    t.status, t.created_at
            FROM    wallet_transactions t
            JOIN    wallets w ON w.id = t.wallet_id
            WHERE   w.user_id = $1
            ORDER BY t.created_at DESC
            LIMIT $2
        `, [userIdInt, limit]);
        return res.rows;
    }

    /**
     * DÉPÔT — Crédite le portefeuille.
     * type : 'deposit' | 'credit' | 'reward' | 'refund'
     */
    async performDeposit(userId, amountRaw, { type = 'deposit', provider, reference, description, orderId, metadata } = {}) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant de dépôt invalide');

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            const wallet = await this._getOrCreateWallet(userId, client);
            if (wallet.is_frozen) throw new Error('Wallet gelé — dépôt impossible');

            const newBalance = parseFloat(wallet.balance) + amount;

            // 1. Mettre à jour le solde
            await client.query(
                `UPDATE wallets SET balance = $1 WHERE id = $2`,
                [newBalance, wallet.id]
            );

            // 2. Enregistrer la transaction
            const tx = await this._insertTx(client, {
                walletId: wallet.id,
                userId,
                type,
                amount,
                balanceAfter: newBalance,
                provider,
                reference,
                description,
                orderId,
                metadata,
            });

            // 3. Sync colonne legacy users.wallet (compatibilité)
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newBalance, parseInt(userId)]);

            await client.query('COMMIT');
            return { transactionId: tx.id, balanceAfter: newBalance };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * RETRAIT — Débite le portefeuille.
     * type : 'withdrawal' | 'payment' | 'transfer'
     * Lève une erreur si solde insuffisant.
     */
    async performWithdrawal(userId, amountRaw, { type = 'withdrawal', provider, reference, description, orderId, metadata } = {}) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant de retrait invalide');

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            const wallet = await this._getOrCreateWallet(userId, client);
            if (wallet.is_frozen) throw new Error('Wallet gelé — retrait impossible');

            const currentBalance = parseFloat(wallet.balance);
            if (currentBalance < amount) {
                throw new Error(`Solde insuffisant (disponible : ${currentBalance.toFixed(2)} USD)`);
            }

            const newBalance = currentBalance - amount;

            // 1. Mettre à jour le solde
            await client.query(
                `UPDATE wallets SET balance = $1 WHERE id = $2`,
                [newBalance, wallet.id]
            );

            // 2. Enregistrer la transaction
            const tx = await this._insertTx(client, {
                walletId: wallet.id,
                userId,
                type,
                amount: -amount,   // négatif pour un débit
                balanceAfter: newBalance,
                provider,
                reference,
                description,
                orderId,
                metadata,
            });

            // 3. Sync colonne legacy users.wallet
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newBalance, parseInt(userId)]);

            await client.query('COMMIT');
            return { transactionId: tx.id, balanceAfter: newBalance };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }
}

module.exports = new WalletRepository();
