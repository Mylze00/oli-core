const pool = require('../config/db');

const COLUMNS = `id, media_type, media_url, poster_url, link_url, title,
                 display_order, is_active, created_at, updated_at`;

/**
 * Accès aux bannières du fil d'accueil (table feed_banners).
 */
class FeedBannerRepository {
    /** Bannières actives pour l'application, dans l'ordre d'affichage. */
    async findAllActive() {
        const result = await pool.query(
            `SELECT ${COLUMNS} FROM feed_banners
             WHERE is_active = TRUE
             ORDER BY display_order ASC, created_at DESC`
        );
        return result.rows;
    }

    /** Toutes les bannières (actives et masquées) pour l'administration. */
    async findAllAdmin() {
        const result = await pool.query(
            `SELECT ${COLUMNS} FROM feed_banners
             ORDER BY display_order ASC, created_at DESC`
        );
        return result.rows;
    }

    async create({ media_type = 'image', media_url, poster_url, link_url, title, is_active = true }) {
        const result = await pool.query(
            `INSERT INTO feed_banners (media_type, media_url, poster_url, link_url, title, display_order, is_active)
             VALUES ($1, $2, $3, $4, $5,
                     (SELECT COALESCE(MAX(display_order), 0) + 1 FROM feed_banners), $6)
             RETURNING ${COLUMNS}`,
            [media_type, media_url, poster_url || null, link_url || '', title || '', is_active]
        );
        return result.rows[0];
    }

    /** Mise à jour partielle : les champs absents (undefined) sont conservés. */
    async update(id, { media_type, media_url, poster_url, link_url, title, is_active }) {
        const result = await pool.query(
            `UPDATE feed_banners
             SET media_type = COALESCE($1, media_type),
                 media_url  = COALESCE($2, media_url),
                 poster_url = CASE WHEN $3::text IS NULL THEN poster_url ELSE NULLIF($3, '') END,
                 link_url   = COALESCE($4, link_url),
                 title      = COALESCE($5, title),
                 is_active  = COALESCE($6, is_active),
                 updated_at = NOW()
             WHERE id = $7
             RETURNING ${COLUMNS}`,
            [media_type ?? null, media_url ?? null, poster_url ?? null, link_url ?? null,
             title ?? null, is_active ?? null, id]
        );
        return result.rows[0];
    }

    async setActive(id, isActive) {
        const result = await pool.query(
            `UPDATE feed_banners SET is_active = $1, updated_at = NOW()
             WHERE id = $2 RETURNING ${COLUMNS}`,
            [isActive, id]
        );
        return result.rows[0];
    }

    /** @param {Array<{ id: number, order: number }>} orders */
    async updateOrder(orders) {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            for (const { id, order } of orders) {
                await client.query(
                    'UPDATE feed_banners SET display_order = $1, updated_at = NOW() WHERE id = $2',
                    [order, id]
                );
            }
            await client.query('COMMIT');
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    async delete(id) {
        const result = await pool.query('DELETE FROM feed_banners WHERE id = $1 RETURNING id', [id]);
        return result.rows.length > 0;
    }
}

module.exports = new FeedBannerRepository();
