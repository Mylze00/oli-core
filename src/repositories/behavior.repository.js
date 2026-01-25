const pool = require("../config/db");

/**
 * Repository pour le tracking comportemental
 */

/**
 * Enregistrer un événement comportemental
 */
async function trackEvent(data) {
    const query = `
        INSERT INTO user_behavior_events (
            user_id, event_type, event_category, event_data,
            session_id, device_type, platform, ip_address, user_agent,
            latitude, longitude, city, country
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        RETURNING *
    `;

    const { rows } = await pool.query(query, [
        data.userId,
        data.eventType,
        data.eventCategory,
        JSON.stringify(data.eventData || {}),
        data.sessionId,
        data.deviceType,
        data.platform,
        data.ipAddress,
        data.userAgent,
        data.latitude,
        data.longitude,
        data.city,
        data.country
    ]);

    return rows[0];
}

/**
 * Récupérer les événements d'un utilisateur
 */
async function findByUserId(userId, limit = 100, offset = 0) {
    const query = `
        SELECT * FROM user_behavior_events
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
    `;

    const { rows } = await pool.query(query, [userId, limit, offset]);
    return rows;
}

/**
 * Récupérer les événements par type
 */
async function findByEventType(eventType, limit = 100) {
    const query = `
        SELECT 
            e.*,
            u.name as user_name,
            u.phone as user_phone
        FROM user_behavior_events e
        JOIN users u ON e.user_id = u.id
        WHERE e.event_type = $1
        ORDER BY e.created_at DESC
        LIMIT $2
    `;

    const { rows } = await pool.query(query, [eventType, limit]);
    return rows;
}

/**
 * Récupérer les statistiques d'événements
 */
async function getEventStats(days = 7) {
    const query = `
        SELECT 
            event_type,
            event_category,
            COUNT(*) as count,
            COUNT(DISTINCT user_id) as unique_users
        FROM user_behavior_events
        WHERE created_at > NOW() - INTERVAL '${days} days'
        GROUP BY event_type, event_category
        ORDER BY count DESC
    `;

    const { rows } = await pool.query(query);
    return rows;
}

/**
 * Récupérer les événements d'une session
 */
async function findBySessionId(sessionId) {
    const query = `
        SELECT * FROM user_behavior_events
        WHERE session_id = $1
        ORDER BY created_at ASC
    `;

    const { rows } = await pool.query(query, [sessionId]);
    return rows;
}

/**
 * Compter les événements d'un utilisateur par type
 */
async function countUserEventsByType(userId, eventType, days = 30) {
    const query = `
        SELECT COUNT(*) as count
        FROM user_behavior_events
        WHERE user_id = $1 
        AND event_type = $2
        AND created_at > NOW() - INTERVAL '${days} days'
    `;

    const { rows } = await pool.query(query, [userId, eventType]);
    return parseInt(rows[0].count);
}

module.exports = {
    trackEvent,
    findByUserId,
    findByEventType,
    getEventStats,
    findBySessionId,
    countUserEventsByType
};
