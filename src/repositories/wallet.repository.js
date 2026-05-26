/**
 * Wallet Repository
 *
 * Gère toutes les opérations de lecture/écriture sur les tables:
 *   - wallets            (solde utilisateur)
 *   - wallet_transactions (historique)
 *
 * Toutes les opérations financières (dépôt, retrait) sont atomiques
 * grâce aux transactions PostgreSQL (BEGIN/COMMIT/ROLLBACK).
 *
 * La devise officielle de OLI est le Franc Congolais (FC).
 */

const pool = require('../config/db');

const walletRepository = {

    /**
     * Récupère le solde actuel d'un utilisateur.
     * @param {number} userId
     * @returns {Promise<number>} solde en FC
     */
    async getBalance(userId) {
        const res = await pool.query(
            'SELECT balance FROM wallets WHERE user_id = $1',
            [parseInt(userId)]
        );
        if (!res.rows.length) {
            throw new Error(`Wallet introuvable pour user #${userId}`);
        }
        return parseFloat(res.rows[0].balance);
    },

    /**
     * Récupère le wallet complet d'un utilisateur.
     * @param {number} userId
     */
    async getWallet(userId) {
        const res = await pool.query(
            'SELECT * FROM wallets WHERE user_id = $1',
            [parseInt(userId)]
        );
        if (!res.rows.length) {
            throw new Error(`Wallet introuvable pour user #${userId}`);
        }
        const w = res.rows[0];
        return { ...w, balance: parseFloat(w.balance) };
    },

    /**
     * Crédite le wallet d'un utilisateur de façon atomique.
     * Vérifie que le wallet n'est pas gelé.
     *
     * @param {number} userId
     * @param {number} amount   - montant à créditer (FC, positif)
     * @param {Object} txData   - { type, provider, reference, description, orderId, metadata }
     * @returns {Promise<{transactionId, balanceBefore, balanceAfter}>}
     */
    async performDeposit(userId, amount, txData = {}) {
        const uid = parseInt(userId);
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // Verrouiller la ligne wallet pour éviter les race conditions
            const walletRes = await client.query(
                'SELECT balance, is_frozen, currency FROM wallets WHERE user_id = $1 FOR UPDATE',
                [uid]
            );

            if (!walletRes.rows.length) {
                throw new Error(`Wallet introuvable pour user #${uid}`);
            }

            const wallet = walletRes.rows[0];
            if (wallet.is_frozen) {
                throw new Error(`Wallet de l'utilisateur #${uid} est gelé`);
            }

            const balanceBefore = parseFloat(wallet.balance);
            const balanceAfter  = balanceBefore + parseFloat(amount);

            // Mettre à jour le solde
            await client.query(
                'UPDATE wallets SET balance = $1 WHERE user_id = $2',
                [balanceAfter, uid]
            );

            // Synchroniser la colonne wallet dans users (compatibilité)
            await client.query(
                'UPDATE users SET wallet = $1 WHERE id = $2',
                [balanceAfter, uid]
            );

            // Créer l'entrée dans l'historique
            const txRes = await client.query(`
                INSERT INTO wallet_transactions
                    (user_id, type, amount, balance_before, balance_after,
                     currency, provider, reference, description, order_id,
                     status, metadata)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'completed',$11)
                RETURNING id
            `, [
                uid,
                txData.type       || 'deposit',
                parseFloat(amount),
                balanceBefore,
                balanceAfter,
                wallet.currency   || 'FC',
                txData.provider   || null,
                txData.reference  || null,
                txData.description|| null,
                txData.orderId    ? parseInt(txData.orderId) : null,
                JSON.stringify(txData.metadata || {}),
            ]);

            await client.query('COMMIT');

            console.log(`💰 Dépôt: +${amount} FC → user #${uid} (${balanceBefore} → ${balanceAfter} FC)`);

            return {
                transactionId: txRes.rows[0].id,
                balanceBefore,
                balanceAfter,
            };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    },

    /**
     * Débite le wallet d'un utilisateur de façon atomique.
     * Vérifie que le solde est suffisant et que le wallet n'est pas gelé.
     *
     * @param {number} userId
     * @param {number} amount   - montant à débiter (FC, positif)
     * @param {Object} txData   - { type, provider, reference, description, orderId, metadata }
     * @returns {Promise<{transactionId, balanceBefore, balanceAfter}>}
     */
    async performDebit(userId, amount, txData = {}) {
        const uid = parseInt(userId);
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            const walletRes = await client.query(
                'SELECT balance, is_frozen, currency FROM wallets WHERE user_id = $1 FOR UPDATE',
                [uid]
            );

            if (!walletRes.rows.length) {
                throw new Error(`Wallet introuvable pour user #${uid}`);
            }

            const wallet = walletRes.rows[0];
            if (wallet.is_frozen) {
                throw new Error(`Wallet de l'utilisateur #${uid} est gelé`);
            }

            const balanceBefore = parseFloat(wallet.balance);
            if (balanceBefore < parseFloat(amount)) {
                throw new Error(`Solde insuffisant: ${balanceBefore} FC disponibles, ${amount} FC requis`);
            }

            const balanceAfter = balanceBefore - parseFloat(amount);

            await client.query(
                'UPDATE wallets SET balance = $1 WHERE user_id = $2',
                [balanceAfter, uid]
            );

            await client.query(
                'UPDATE users SET wallet = $1 WHERE id = $2',
                [balanceAfter, uid]
            );

            const txRes = await client.query(`
                INSERT INTO wallet_transactions
                    (user_id, type, amount, balance_before, balance_after,
                     currency, provider, reference, description, order_id,
                     status, metadata)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'completed',$11)
                RETURNING id
            `, [
                uid,
                txData.type       || 'withdrawal',
                -parseFloat(amount),
                balanceBefore,
                balanceAfter,
                wallet.currency   || 'FC',
                txData.provider   || null,
                txData.reference  || null,
                txData.description|| null,
                txData.orderId    ? parseInt(txData.orderId) : null,
                JSON.stringify(txData.metadata || {}),
            ]);

            await client.query('COMMIT');

            console.log(`💸 Débit: -${amount} FC ← user #${uid} (${balanceBefore} → ${balanceAfter} FC)`);

            return {
                transactionId: txRes.rows[0].id,
                balanceBefore,
                balanceAfter,
            };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    },

    /**
     * Récupère l'historique des transactions d'un utilisateur.
     * @param {number} userId
     * @param {number} limit
     * @param {number} offset
     */
    async getHistory(userId, limit = 20, offset = 0) {
        const res = await pool.query(`
            SELECT id, type, amount, balance_before, balance_after,
                   currency, provider, reference, description,
                   status, created_at, metadata
            FROM   wallet_transactions
            WHERE  user_id = $1
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
        `, [parseInt(userId), Math.min(limit, 100), offset]);

        return res.rows.map(tx => ({
            ...tx,
            amount:         parseFloat(tx.amount),
            balance_before: parseFloat(tx.balance_before),
            balance_after:  parseFloat(tx.balance_after),
        }));
    },

    /**
     * Gèle ou dégèle un wallet (admin).
     */
    async setFrozen(userId, frozen) {
        await pool.query(
            'UPDATE wallets SET is_frozen = $1 WHERE user_id = $2',
            [Boolean(frozen), parseInt(userId)]
        );
    },

    /**
     * Crée un wallet pour un nouvel utilisateur.
     * Appelé lors de l'inscription.
     */
    async createWallet(userId) {
        await pool.query(`
            INSERT INTO wallets (user_id, balance, currency)
            VALUES ($1, 0, 'FC')
            ON CONFLICT (user_id) DO NOTHING
        `, [parseInt(userId)]);
        console.log(`👛 Wallet créé pour user #${userId}`);
    },
};

module.exports = walletRepository;
