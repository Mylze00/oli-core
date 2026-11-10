/**
 * Présence en ligne : sait qui est connecté et ne prévient que ses interlocuteurs.
 */
const pool = require('../config/db');

// Un utilisateur peut avoir plusieurs connexions ouvertes (téléphone, navigateur)
const connectionCounts = new Map();

function isOnline(userId) {
    return (connectionCounts.get(String(userId)) || 0) > 0;
}

async function notifyPartners(io, userId, online) {
    try {
        const { rows } = await pool.query(
            `SELECT DISTINCT other.user_id
             FROM conversation_participants mine
             JOIN conversation_participants other
               ON other.conversation_id = mine.conversation_id AND other.user_id <> mine.user_id
             WHERE mine.user_id = $1`,
            [userId]
        );
        for (const { user_id: partnerId } of rows) {
            io.to(`user_${partnerId}`).emit('user_online', { userId, online });
        }
    } catch (err) {
        console.error('⚠️ Présence non diffusée:', err.message);
    }
}

function userConnected(io, userId) {
    const key = String(userId);
    const count = connectionCounts.get(key) || 0;
    connectionCounts.set(key, count + 1);
    if (count === 0) notifyPartners(io, userId, true);
}

function userDisconnected(io, userId) {
    const key = String(userId);
    const count = (connectionCounts.get(key) || 1) - 1;
    if (count > 0) {
        connectionCounts.set(key, count);
        return;
    }
    connectionCounts.delete(key);
    notifyPartners(io, userId, false);
}

module.exports = { isOnline, userConnected, userDisconnected };
