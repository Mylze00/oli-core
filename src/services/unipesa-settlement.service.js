/**
 * Règlement des opérations Unipesa (dépôts et retraits).
 *
 * Source de vérité : la ligne unipesa_operations créée à l'initiation (montant,
 * utilisateur, type). Le montant envoyé dans un webhook n'est JAMAIS utilisé
 * pour créditer ou rembourser.
 *
 * Idempotence : settled_at est posé une seule fois (verrou atomique). Le webhook
 * et le polling passent par les mêmes fonctions, donc un même événement ne peut
 * pas créditer deux fois.
 */
const pool = require('../config/db');
const walletRepository = require('../repositories/wallet.repository');
const { FEES } = require('../config/index');

/** Charge l'opération (sans verrou). */
async function findOperation(oliOrderId, operationType) {
    const { rows } = await pool.query(
        `SELECT * FROM unipesa_operations
         WHERE oli_order_id = $1 AND operation_type = $2`,
        [oliOrderId, operationType]
    );
    return rows[0] || null;
}

/** Pose le verrou de règlement. Retourne la ligne si on est le premier, sinon null. */
async function claimSettlement(operationId) {
    const { rows } = await pool.query(
        `UPDATE unipesa_operations SET settled_at = NOW()
         WHERE id = $1 AND settled_at IS NULL
         RETURNING *`,
        [operationId]
    );
    return rows[0] || null;
}

/** Libère le verrou (échec pendant le mouvement d'argent : nouvelle tentative possible). */
async function releaseSettlement(operationId) {
    await pool.query(
        'UPDATE unipesa_operations SET settled_at = NULL WHERE id = $1',
        [operationId]
    );
}

/**
 * Crédite un dépôt confirmé.
 * @param {string} oliOrderId
 * @param {number} expectedUserId - utilisateur déduit de la référence (DEP-<id>-…)
 * @returns {Promise<{status: 'credited'|'not_found'|'user_mismatch'|'already_settled', ...}>}
 */
async function settleDeposit(oliOrderId, expectedUserId) {
    const op = await findOperation(oliOrderId, 'deposit');
    if (!op) return { status: 'not_found' };
    if (Number(op.user_id) !== Number(expectedUserId)) return { status: 'user_mismatch' };

    const claimed = await claimSettlement(op.id);
    if (!claimed) return { status: 'already_settled' };

    // Garde-fou supplémentaire : pas de double crédit même si le verrou a été perdu
    const dup = await pool.query(
        `SELECT 1 FROM wallet_transactions WHERE reference = $1 AND type = 'deposit' LIMIT 1`,
        [oliOrderId]
    );
    if (dup.rows.length > 0) return { status: 'already_settled' };

    try {
        const gross = parseFloat(claimed.amount_fc);
        const net = gross / (1 + FEES.TOTAL_DEPOSIT_RATE);
        const fee = gross - net;

        await walletRepository.performDeposit(claimed.user_id, net, {
            type: 'deposit',
            provider: 'UNIPESA',
            reference: oliOrderId,
            description: `Recharge Mobile Money confirmée — ${gross} FC brut`,
        });

        await pool.query(
            `UPDATE unipesa_operations SET status = 'success', confirmed_at = NOW()
             WHERE id = $1`,
            [claimed.id]
        );

        if (fee > 0) {
            const walletService = require('./wallet.service');
            await walletService._creditSystemWallet(
                fee,
                `${oliOrderId}_FEE`,
                `Frais ${(FEES.TOTAL_DEPOSIT_RATE * 100).toFixed(0)}% recharge (User #${claimed.user_id}) — ${gross} FC`
            );
        }

        return {
            status: 'credited',
            userId: claimed.user_id,
            grossFC: gross,
            netFC: net,
            feeFC: fee,
        };
    } catch (err) {
        await releaseSettlement(claimed.id);
        throw err;
    }
}

/** Marque un retrait comme réussi (aucun mouvement d'argent : le débit a déjà eu lieu). */
async function settleWithdrawalSuccess(oliOrderId, expectedUserId) {
    const op = await findOperation(oliOrderId, 'withdrawal');
    if (!op) return { status: 'not_found' };
    if (Number(op.user_id) !== Number(expectedUserId)) return { status: 'user_mismatch' };

    await pool.query(
        `UPDATE unipesa_operations SET status = 'success', confirmed_at = NOW()
         WHERE id = $1 AND status <> 'failed'`,
        [op.id]
    );
    await pool.query(
        `UPDATE wallet_transactions SET status = 'completed'
         WHERE reference = $1`,
        [oliOrderId]
    );
    return { status: 'confirmed' };
}

/**
 * Rembourse un retrait en échec, exactement ce qui a été débité :
 * montant net + frais OLI (3 %). Les frais déjà versés à la banque OLI sont retirés.
 */
async function settleWithdrawalFailure(oliOrderId, expectedUserId) {
    const op = await findOperation(oliOrderId, 'withdrawal');
    if (!op) return { status: 'not_found' };
    if (Number(op.user_id) !== Number(expectedUserId)) return { status: 'user_mismatch' };

    const claimed = await claimSettlement(op.id);
    if (!claimed) return { status: 'already_settled' };

    try {
        const net = parseFloat(claimed.amount_fc);
        const fee = net * FEES.OLI_WITHDRAW_RATE;
        const refund = net + fee;

        await walletRepository.performDeposit(claimed.user_id, refund, {
            type: 'refund',
            provider: 'UNIPESA',
            reference: `${oliOrderId}_REFUND`,
            description: `Remboursement : échec du retrait Unipesa (${net} FC + ${fee.toFixed(0)} FC frais)`,
        });

        // Retirer les frais précédemment versés à la banque OLI
        if (fee > 0) {
            await pool.query('UPDATE wallets SET balance = balance - $1 WHERE user_id = 0', [fee]);
            await pool.query('UPDATE users SET wallet = wallet - $1 WHERE id = 0', [fee]);
        }

        await pool.query(
            `UPDATE unipesa_operations SET status = 'failed'
             WHERE id = $1`,
            [claimed.id]
        );
        await pool.query(
            `UPDATE wallet_transactions SET status = 'failed'
             WHERE reference = $1`,
            [oliOrderId]
        );

        return { status: 'refunded', userId: claimed.user_id, refundFC: refund };
    } catch (err) {
        await releaseSettlement(claimed.id);
        throw err;
    }
}

module.exports = {
    settleDeposit,
    settleWithdrawalSuccess,
    settleWithdrawalFailure,
};
