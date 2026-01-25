const pool = require("../config/db");

/**
 * Repository pour la gestion de l'historique des avatars
 */

/**
 * Enregistrer un nouvel avatar
 */
async function createAvatarRecord(data) {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Marquer tous les anciens avatars comme non-courants
        await client.query(
            `UPDATE user_avatar_history 
             SET is_current = false 
             WHERE user_id = $1`,
            [data.userId]
        );

        // Insérer le nouvel avatar
        const query = `
            INSERT INTO user_avatar_history (
                user_id, avatar_url, storage_provider,
                file_size_bytes, mime_type, is_current
            )
            VALUES ($1, $2, $3, $4, $5, true)
            RETURNING *
        `;

        const { rows } = await client.query(query, [
            data.userId,
            data.avatarUrl,
            data.storageProvider || 'cloudinary',
            data.fileSizeBytes,
            data.mimeType
        ]);

        await client.query('COMMIT');
        return rows[0];
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

/**
 * Récupérer l'avatar actuel d'un utilisateur
 */
async function getCurrentAvatar(userId) {
    const query = `
        SELECT * FROM user_avatar_history
        WHERE user_id = $1 AND is_current = true
        LIMIT 1
    `;

    const { rows } = await pool.query(query, [userId]);
    return rows[0];
}

/**
 * Récupérer l'historique des avatars d'un utilisateur
 */
async function getAvatarHistory(userId, limit = 10) {
    const query = `
        SELECT * FROM user_avatar_history
        WHERE user_id = $1
        ORDER BY uploaded_at DESC
        LIMIT $2
    `;

    const { rows } = await pool.query(query, [userId, limit]);
    return rows;
}

/**
 * Restaurer un avatar précédent
 */
async function restoreAvatar(userId, avatarId) {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Marquer tous les avatars comme non-courants
        await client.query(
            `UPDATE user_avatar_history 
             SET is_current = false 
             WHERE user_id = $1`,
            [userId]
        );

        // Marquer l'avatar sélectionné comme courant
        const query = `
            UPDATE user_avatar_history
            SET is_current = true
            WHERE id = $1 AND user_id = $2
            RETURNING *
        `;

        const { rows } = await client.query(query, [avatarId, userId]);

        if (rows.length === 0) {
            throw new Error('Avatar not found or unauthorized');
        }

        // Mettre à jour l'avatar dans la table users
        await client.query(
            `UPDATE users SET avatar_url = $1 WHERE id = $2`,
            [rows[0].avatar_url, userId]
        );

        await client.query('COMMIT');
        return rows[0];
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

/**
 * Supprimer un avatar de l'historique
 */
async function deleteAvatar(userId, avatarId) {
    const query = `
        DELETE FROM user_avatar_history
        WHERE id = $1 AND user_id = $2 AND is_current = false
        RETURNING *
    `;

    const { rows } = await pool.query(query, [avatarId, userId]);
    return rows[0];
}

module.exports = {
    createAvatarRecord,
    getCurrentAvatar,
    getAvatarHistory,
    restoreAvatar,
    deleteAvatar
};
