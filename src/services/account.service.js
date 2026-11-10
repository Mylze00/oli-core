/**
 * Suppression de compte utilisateur — suppression logique avec anonymisation.
 *
 * Principe : aucune ligne financière ou de commande n'est supprimée, car elles
 * référencent users(id) sans ON DELETE CASCADE (commandes, wallets, transactions).
 * On anonymise l'identité, on retire les données personnelles accessoires et on
 * bloque la suppression tant qu'une opération est en cours (solde, commande, retrait).
 */
const pool = require('../config/db');
const { invalidateAccountCache } = require('../middlewares/auth.middleware');

/** Statuts de commande considérés comme terminés (ne bloquent pas la suppression). */
const CLOSED_ORDER_STATUSES = ['delivered', 'cancelled', 'refunded'];

/**
 * Vérifie que le compte peut être supprimé.
 * @returns {Promise<string[]>} liste des raisons de blocage (vide si OK)
 */
async function getDeletionBlockers(userId, client = pool) {
    const reasons = [];

    const wallet = await client.query(
        'SELECT balance FROM wallets WHERE user_id = $1',
        [userId]
    );
    const balance = wallet.rows.length ? parseFloat(wallet.rows[0].balance) : 0;
    if (balance > 0) {
        reasons.push(`Solde non nul (${balance.toFixed(0)} FC) : retirez votre solde avant de supprimer le compte.`);
    }

    const pendingOps = await client.query(
        `SELECT COUNT(*)::int AS n FROM unipesa_operations
         WHERE user_id = $1 AND status = 'pending'`,
        [userId]
    );
    if (pendingOps.rows[0].n > 0) {
        reasons.push('Une opération Mobile Money est en attente de confirmation.');
    }

    const openBuyerOrders = await client.query(
        `SELECT COUNT(*)::int AS n FROM orders
         WHERE user_id = $1 AND NOT (status = ANY($2::text[]))`,
        [userId, CLOSED_ORDER_STATUSES]
    );
    if (openBuyerOrders.rows[0].n > 0) {
        reasons.push('Vous avez des commandes en cours (achat).');
    }

    const openSellerOrders = await client.query(
        `SELECT COUNT(*)::int AS n FROM orders
         WHERE seller_id = $1 AND NOT (status = ANY($2::text[]))`,
        [userId, CLOSED_ORDER_STATUSES]
    );
    if (openSellerOrders.rows[0].n > 0) {
        reasons.push('Vous avez des commandes en cours (vente) à traiter.');
    }

    return reasons;
}

/**
 * Supprime (logiquement) le compte.
 * @returns {Promise<{success: boolean, blockers?: string[]}>}
 */
async function deleteAccount(userId) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // Déjà supprimé ? (idempotence)
        const current = await client.query(
            'SELECT deleted_at FROM users WHERE id = $1 FOR UPDATE',
            [userId]
        );
        if (current.rows.length === 0) {
            await client.query('ROLLBACK');
            return { success: false, notFound: true };
        }
        if (current.rows[0].deleted_at) {
            await client.query('ROLLBACK');
            return { success: true, alreadyDeleted: true };
        }

        const blockers = await getDeletionBlockers(userId, client);
        if (blockers.length > 0) {
            await client.query('ROLLBACK');
            return { success: false, blockers };
        }

        // 1. Anonymiser l'identité. Le téléphone est remplacé par une valeur unique,
        //    ce qui libère le numéro : il pourra servir à un nouveau compte.
        await client.query(
            `UPDATE users SET
                name = 'Compte supprimé',
                phone = 'del_' || id,
                avatar_url = NULL,
                otp_code = NULL,
                otp_expires_at = NULL,
                is_admin = FALSE,
                is_seller = FALSE,
                is_deliverer = FALSE,
                deleted_at = NOW(),
                updated_at = NOW()
             WHERE id = $1`,
            [userId]
        );

        // 2. Retirer les produits du catalogue (soft delete existant : status = 'deleted')
        await client.query(
            `UPDATE products SET status = 'deleted', updated_at = NOW()
             WHERE seller_id = $1 AND status <> 'deleted'`,
            [userId]
        );

        // 3. Fermer les boutiques
        await client.query(
            'UPDATE shops SET is_active = FALSE WHERE owner_id = $1',
            [userId]
        );

        // 4. Données personnelles accessoires (non financières) : suppression
        await client.query('DELETE FROM device_tokens WHERE user_id = $1', [userId]);
        await client.query('DELETE FROM addresses WHERE user_id = $1', [userId]);
        await client.query('DELETE FROM user_product_views WHERE user_id = $1', [userId]);
        await client.query('DELETE FROM notifications WHERE user_id = $1', [userId]);

        await client.query('COMMIT');

        // Effet immédiat : le JWT de ce compte n'est plus accepté sur ce processus
        invalidateAccountCache(userId);
        return { success: true };
    } catch (err) {
        await client.query('ROLLBACK');
        throw err;
    } finally {
        client.release();
    }
}

module.exports = {
    deleteAccount,
    getDeletionBlockers,
};
