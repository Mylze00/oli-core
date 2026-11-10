/**
 * Atteste les messages d'envoi d'argent de la messagerie.
 *
 * Un billet ne s'affiche que si `metadata.cash_transfer` existe : seul ce service peut
 * l'écrire, après avoir retrouvé le transfert réel dans wallet_transactions.
 */
const pool = require('../config/db');

function toMetadataObject(metadata) {
    let value = metadata;
    if (typeof value === 'string') {
        try { value = JSON.parse(value); } catch (e) { return {}; }
    }
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

/**
 * Renvoie des métadonnées sûres à enregistrer.
 * Le billet réclamé est retiré si le transfert n'existe pas entre les deux participants
 * de la conversation, ou s'il a déjà servi à un autre message.
 */
async function attestCashTransfer(metadata, { conversationId, senderId, recipientId }) {
    const { cash_transfer: claim, ...safeMetadata } = toMetadataObject(metadata);
    const reference = claim && claim.reference;
    if (typeof reference !== 'string' || !recipientId) return safeMetadata;

    const { rows } = await pool.query(
        `SELECT credit.amount
         FROM wallet_transactions debit
         JOIN wallet_transactions credit ON credit.reference = debit.reference
         WHERE debit.reference = $1
           AND debit.user_id = $2 AND debit.type = 'transfer' AND debit.amount < 0
           AND credit.user_id = $3 AND credit.type = 'transfer' AND credit.amount > 0
           AND EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = $4 AND user_id = $2)
           AND EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = $4 AND user_id = $3)
           AND NOT EXISTS (
               SELECT 1 FROM messages m
               WHERE m.metadata ? 'cash_transfer'
                 AND m.metadata->'cash_transfer'->>'reference' = $1
           )`,
        [reference, senderId, recipientId, conversationId]
    );
    if (rows.length === 0) return safeMetadata;

    return { ...safeMetadata, cash_transfer: { reference, amount_fc: Number(rows[0].amount), currency: 'FC' } };
}

module.exports = { attestCashTransfer };
