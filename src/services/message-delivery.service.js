/**
 * Marque comme distribués les messages en attente quand leur destinataire se connecte.
 */
const pool = require('../config/db');

async function markPendingDelivered(io, userId) {
    try {
        const { rows } = await pool.query(
            `UPDATE messages m
             SET delivered_at = NOW()
             FROM conversation_participants cp
             WHERE cp.user_id = $1
               AND m.conversation_id = cp.conversation_id
               AND m.sender_id <> $1
               AND m.delivered_at IS NULL
               AND m.is_read = FALSE
             RETURNING m.conversation_id, m.sender_id`,
            [userId]
        );

        const notified = new Set();
        for (const { conversation_id: conversationId, sender_id: senderId } of rows) {
            const key = `${conversationId}:${senderId}`;
            if (notified.has(key)) continue;
            notified.add(key);
            io.to(`user_${senderId}`).emit('messages_delivered', {
                conversation_id: conversationId,
                recipient_id: userId,
            });
        }
    } catch (err) {
        console.error('⚠️ Distribution des messages non enregistrée:', err.message);
    }
}

module.exports = { markPendingDelivered };
