const pool = require("../config/db");

/**
 * Repository pour la gestion des niveaux de vérification utilisateur
 */

/**
 * Récupérer le niveau de vérification d'un utilisateur
 */
async function findByUserId(userId) {
    const query = `
        SELECT * FROM user_verification_levels
        WHERE user_id = $1
    `;

    const { rows } = await pool.query(query, [userId]);
    return rows[0];
}

/**
 * Mettre à jour la vérification du téléphone
 */
async function updatePhoneVerification(userId, verified) {
    const query = `
        UPDATE user_verification_levels
        SET 
            phone_verified = $1,
            phone_verified_at = CASE WHEN $1 = true THEN NOW() ELSE phone_verified_at END,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [verified, userId]);
    return rows[0];
}

/**
 * Mettre à jour la vérification de l'email
 */
async function updateEmailVerification(userId, verified) {
    const query = `
        UPDATE user_verification_levels
        SET 
            email_verified = $1,
            email_verified_at = CASE WHEN $1 = true THEN NOW() ELSE email_verified_at END,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [verified, userId]);
    return rows[0];
}

/**
 * Mettre à jour la vérification de l'identité
 */
async function updateIdentityVerification(userId, verified) {
    const query = `
        UPDATE user_verification_levels
        SET 
            identity_verified = $1,
            identity_verified_at = CASE WHEN $1 = true THEN NOW() ELSE identity_verified_at END,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [verified, userId]);
    return rows[0];
}

/**
 * Mettre à jour la vérification de l'adresse
 */
async function updateAddressVerification(userId, verified) {
    const query = `
        UPDATE user_verification_levels
        SET 
            address_verified = $1,
            address_verified_at = CASE WHEN $1 = true THEN NOW() ELSE address_verified_at END,
            updated_at = NOW()
        WHERE user_id = $2
        RETURNING *
    `;

    const { rows } = await pool.query(query, [verified, userId]);
    return rows[0];
}

/**
 * Récupérer les statistiques de vérification
 */
async function getVerificationStats() {
    const query = `
        SELECT 
            verification_level,
            COUNT(*) as count,
            ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
        FROM user_verification_levels
        GROUP BY verification_level
        ORDER BY 
            CASE verification_level
                WHEN 'premium' THEN 1
                WHEN 'advanced' THEN 2
                WHEN 'intermediate' THEN 3
                WHEN 'basic' THEN 4
                WHEN 'unverified' THEN 5
            END
    `;

    const { rows } = await pool.query(query);
    return rows;
}

/**
 * Récupérer les utilisateurs par niveau de vérification
 */
async function findByVerificationLevel(level, limit = 50, offset = 0) {
    const query = `
        SELECT 
            vl.*,
            u.name,
            u.phone,
            u.id_oli,
            u.avatar_url
        FROM user_verification_levels vl
        JOIN users u ON vl.user_id = u.id
        WHERE vl.verification_level = $1
        ORDER BY vl.updated_at DESC
        LIMIT $2 OFFSET $3
    `;

    const { rows } = await pool.query(query, [level, limit, offset]);
    return rows;
}

module.exports = {
    findByUserId,
    updatePhoneVerification,
    updateEmailVerification,
    updateIdentityVerification,
    updateAddressVerification,
    getVerificationStats,
    findByVerificationLevel
};
