const pool = require("../config/db");

/**
 * Repository pour la gestion des trust scores
 */

/**
 * Récupérer le trust score d'un utilisateur
 */
async function findByUserId(userId) {
    const query = `
        SELECT * FROM user_trust_scores
        WHERE user_id = $1
    `;

    const { rows } = await pool.query(query, [userId]);
    return rows[0];
}

/**
 * Mettre à jour le score d'identité
 */
async function updateIdentityScore(userId, score) {
    const query = `
        UPDATE user_trust_scores
        SET 
            identity_score = $1,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [score, userId]);
    return rows[0];
}

/**
 * Mettre à jour le score de transaction
 */
async function updateTransactionScore(userId, score) {
    const query = `
        UPDATE user_trust_scores
        SET 
            transaction_score = $1,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [score, userId]);
    return rows[0];
}

/**
 * Mettre à jour le score de comportement
 */
async function updateBehaviorScore(userId, score) {
    const query = `
        UPDATE user_trust_scores
        SET 
            behavior_score = $1,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [score, userId]);
    return rows[0];
}

/**
 * Mettre à jour le niveau de risque de fraude
 */
async function updateFraudRiskLevel(userId, level, reason = null) {
    const query = `
        UPDATE user_trust_scores
        SET 
            fraud_risk_level = $1,
            is_flagged = CASE WHEN $1 IN ('high', 'critical') THEN true ELSE false END,
            flag_reason = $2,
            updated_at = NOW()
        WHERE user_id = $3
        RETURNING *
    `;

    const { rows } = await pool.query(query, [level, reason, userId]);
    return rows[0];
}

/**
 * Récupérer les utilisateurs à risque
 */
async function findHighRiskUsers(limit = 50) {
    const query = `
        SELECT 
            ts.*,
            u.name,
            u.phone,
            u.id_oli,
            u.avatar_url
        FROM user_trust_scores ts
        JOIN users u ON ts.user_id = u.id
        WHERE ts.fraud_risk_level IN ('high', 'critical')
        OR ts.is_flagged = true
        ORDER BY 
            CASE ts.fraud_risk_level
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                ELSE 4
            END,
            ts.overall_score ASC
        LIMIT $1
    `;

    const { rows } = await pool.query(query, [limit]);
    return rows;
}

/**
 * Récupérer les statistiques de trust score
 */
async function getTrustScoreStats() {
    const query = `
        SELECT 
            ROUND(AVG(overall_score), 2) as avg_score,
            ROUND(AVG(identity_score), 2) as avg_identity,
            ROUND(AVG(transaction_score), 2) as avg_transaction,
            ROUND(AVG(behavior_score), 2) as avg_behavior,
            ROUND(AVG(social_score), 2) as avg_social,
            COUNT(*) FILTER (WHERE fraud_risk_level = 'low') as low_risk_count,
            COUNT(*) FILTER (WHERE fraud_risk_level = 'medium') as medium_risk_count,
            COUNT(*) FILTER (WHERE fraud_risk_level = 'high') as high_risk_count,
            COUNT(*) FILTER (WHERE fraud_risk_level = 'critical') as critical_risk_count,
            COUNT(*) FILTER (WHERE is_flagged = true) as flagged_count
        FROM user_trust_scores
    `;

    const { rows } = await pool.query(query);
    return rows[0];
}

/**
 * Recalculer le trust score global d'un utilisateur
 */
async function recalculateOverallScore(userId) {
    const query = `SELECT calculate_overall_trust_score($1) as score`;
    const { rows } = await pool.query(query, [userId]);
    return rows[0].score;
}

module.exports = {
    findByUserId,
    updateIdentityScore,
    updateTransactionScore,
    updateBehaviorScore,
    updateFraudRiskLevel,
    findHighRiskUsers,
    getTrustScoreStats,
    recalculateOverallScore
};
