/**
 * Repository pour les notifications
 * Gère toutes les opérations sur la table notifications
 */

const pool = require('../config/db');

class NotificationRepository {
    /**
     * Créer une nouvelle notification
     */
    async create(userId, type, title, body, data = null) {
        console.log(`📝 [NotificationRepo] Création notification pour user ${userId}`);
        console.log(`   - Type: ${type}`);
        console.log(`   - Title: ${title}`);

        const query = `
      INSERT INTO notifications (user_id, type, title, body, data)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `;

        const result = await pool.query(query, [
            userId,
            type,
            title,
            body,
            data ? JSON.stringify(data) : null
        ]);

        console.log(`   ✅ Notification créée: ID ${result.rows[0].id}`);
        return result.rows[0];
    }

    /**
     * Récupérer toutes les notifications d'un utilisateur
     */
    async findByUser(userId, limit = 50) {
        const query = `
      SELECT * FROM notifications
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2
    `;

        const result = await pool.query(query, [userId, limit]);
        return result.rows;
    }

    /**
     * Compter les notifications non lues
     */
    async countUnread(userId) {
        const query = `
      SELECT COUNT(*) as count FROM notifications
      WHERE user_id = $1 AND is_read = FALSE
    `;

        const result = await pool.query(query, [userId]);
        return parseInt(result.rows[0].count, 10);
    }

    /**
     * Marquer une notification comme lue
     */
    async markAsRead(id, userId) {
        const query = `
      UPDATE notifications
      SET is_read = TRUE, updated_at = NOW()
      WHERE id = $1 AND user_id = $2
      RETURNING *
    `;

        const result = await pool.query(query, [id, userId]);
        return result.rows[0];
    }

    /**
     * Marquer toutes les notifications comme lues
     */
    async markAllAsRead(userId) {
        const query = `
      UPDATE notifications
      SET is_read = TRUE, updated_at = NOW()
      WHERE user_id = $1 AND is_read = FALSE
    `;

        const result = await pool.query(query, [userId]);
        return result.rowCount;
    }

    /**
     * Supprimer une notification
     */
    async delete(id, userId) {
        const query = `
      DELETE FROM notifications
      WHERE id = $1 AND user_id = $2
    `;

        const result = await pool.query(query, [id, userId]);
        return result.rowCount > 0;
    }

    /**
     * Supprimer toutes les notifications lues d'un utilisateur
     */
    async deleteAllRead(userId) {
        const query = `
      DELETE FROM notifications
      WHERE user_id = $1 AND is_read = TRUE
    `;

        const result = await pool.query(query, [userId]);
        return result.rowCount;
    }
}

module.exports = new NotificationRepository();
