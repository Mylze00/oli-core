/**
 * Historique des appels et identité affichée à l'appel entrant.
 */
const pool = require('../config/db');

const LATEST_CALL_FROM_CALLER = `(
    SELECT id FROM call_logs
    WHERE caller_id = $1 AND receiver_id = $2
    ORDER BY created_at DESC LIMIT 1
)`;

async function updateCallStatus(callerId, receiverId, status) {
    await pool.query(
        `UPDATE call_logs SET status = $3, ended_at = NOW() WHERE id = ${LATEST_CALL_FROM_CALLER}`,
        [callerId, receiverId, status]
    );
}

async function markCallAnswered(callerId, receiverId) {
    await pool.query(
        `UPDATE call_logs SET status = 'answered', answered_at = NOW() WHERE id = ${LATEST_CALL_FROM_CALLER}`,
        [callerId, receiverId]
    );
}

/** Clôt le dernier appel entre deux personnes, quel que soit celui qui raccroche. */
async function finishAnsweredCall(userId, otherUserId) {
    await pool.query(
        `UPDATE call_logs
         SET ended_at = NOW(),
             duration_seconds = EXTRACT(EPOCH FROM (NOW() - COALESCE(answered_at, created_at)))
         WHERE id = (
             SELECT id FROM call_logs
             WHERE (caller_id = $1 AND receiver_id = $2) OR (caller_id = $2 AND receiver_id = $1)
             ORDER BY created_at DESC LIMIT 1
         )
           AND status = 'answered'
           AND ended_at IS NULL`,
        [userId, otherUserId]
    );
}

/** Le nom vient de la base : un nom envoyé par l'appelant permettrait d'usurper un compte. */
async function getCallIdentity(userId) {
    const { rows } = await pool.query(
        `SELECT id, name, avatar_url, is_verified, account_type, has_certified_shop, subscription_plan
         FROM users
         WHERE id = $1 AND deleted_at IS NULL`,
        [userId]
    );
    if (rows.length === 0) return null;
    return { ...rows[0], name: rows[0].name || 'Utilisateur OLI' };
}

module.exports = { updateCallStatus, markCallAnswered, finishAnsweredCall, getCallIdentity };
