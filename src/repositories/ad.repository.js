const pool = require('../config/db');

class AdRepository {
    /**
     * Récupère toutes les pubs actives pour l'app mobile (ordonnées par display_order ASC)
     */
    async findAllActive() {
        const result = await pool.query(`
            SELECT id, image_url, title, link_url, display_order, is_active, created_at 
            FROM ads 
            WHERE is_active = TRUE 
            ORDER BY display_order ASC, created_at DESC
        `);
        return result.rows;
    }

    /**
     * Récupère toutes les pubs pour l'administration (actives + inactives, ordonnées)
     */
    async findAllAdmin() {
        const result = await pool.query(`
            SELECT id, image_url, title, link_url, display_order, is_active, created_at, updated_at 
            FROM ads 
            ORDER BY display_order ASC, created_at DESC
        `);
        return result.rows;
    }

    /**
     * Crée une nouvelle pub
     */
    async create(adData) {
        const { image_url, title, link_url, display_order, is_active = true } = adData;
        
        let order = display_order;
        if (order === undefined || order === null) {
            // Obtenir le max display_order actuel + 1
            const maxOrderRes = await pool.query("SELECT COALESCE(MAX(display_order), 0) + 1 AS next_order FROM ads");
            order = maxOrderRes.rows[0].next_order;
        }

        const result = await pool.query(
            `INSERT INTO ads (image_url, title, link_url, display_order, is_active) 
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING *`,
            [image_url, title || '', link_url || '', order, is_active]
        );
        return result.rows[0];
    }

    /**
     * Met à jour une pub
     */
    async update(id, adData) {
        const { image_url, title, link_url, display_order, is_active } = adData;
        const result = await pool.query(
            `UPDATE ads 
             SET image_url = COALESCE($1, image_url),
                 title = COALESCE($2, title),
                 link_url = COALESCE($3, link_url),
                 display_order = COALESCE($4, display_order),
                 is_active = COALESCE($5, is_active),
                 updated_at = NOW()
             WHERE id = $6
             RETURNING *`,
            [image_url, title, link_url, display_order, is_active, id]
        );
        return result.rows[0];
    }

    /**
     * Supprime une pub
     */
    async delete(id) {
        const result = await pool.query("DELETE FROM ads WHERE id = $1 RETURNING id", [id]);
        return result.rows.length > 0;
    }

    /**
     * Active ou désactive une pub
     */
    async toggleActive(id, isActive) {
        const result = await pool.query(
            `UPDATE ads 
             SET is_active = $1, 
                 updated_at = NOW() 
             WHERE id = $2 
             RETURNING *`,
            [isActive, id]
        );
        return result.rows[0];
    }

    /**
     * Met à jour l'ordre de plusieurs pubs (Batch reorder)
     * @param {Array<{ id: number, order: number }>} orders
     */
    async updateOrder(orders) {
        if (!Array.isArray(orders) || orders.length === 0) return true;

        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            for (const item of orders) {
                await client.query(
                    `UPDATE ads 
                     SET display_order = $1, 
                         updated_at = NOW() 
                     WHERE id = $2`,
                    [item.order, item.id]
                );
            }
            await client.query('COMMIT');
            return true;
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }
}

module.exports = new AdRepository();
