/**
 * Service Video Sales — Live Shopping MVP
 * Gère les vidéos de vente pré-enregistrées
 */
const pool = require('../config/db');

class VideoSalesService {

    /**
     * Auto-migration : créer les tables si elles n'existent pas
     */
    async ensureTables() {
        try {
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_sales (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    product_id INTEGER REFERENCES products(id),
                    video_url TEXT NOT NULL,
                    thumbnail_url TEXT,
                    title VARCHAR(150),
                    description TEXT,
                    duration_seconds INTEGER,
                    views_count INTEGER DEFAULT 0,
                    likes_count INTEGER DEFAULT 0,
                    status VARCHAR(20) DEFAULT 'active',
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
            `);
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_likes (
                    id SERIAL PRIMARY KEY,
                    video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    UNIQUE(video_id, user_id)
                )
            `);
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_views (
                    id SERIAL PRIMARY KEY,
                    video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    UNIQUE(video_id, user_id)
                )
            `);
            console.log('✅ Tables video_sales prêtes');
        } catch (err) {
            console.error('❌ Erreur migration video_sales:', err.message);
        }
    }

    /**
     * Récupérer le feed paginé
     */
    async getFeed(page = 1, limit = 10, currentUserId = null) {
        const offset = (page - 1) * limit;

        const query = `
            SELECT 
                v.id, v.video_url, v.thumbnail_url, v.title, v.description,
                v.duration_seconds, v.views_count, v.likes_count,
                v.product_id, v.created_at,
                u.id AS seller_id, u.name AS seller_name, u.avatar_url AS seller_avatar,
                u.has_certified_shop AS seller_certified,
                p.name AS product_name, p.price AS product_price, 
                p.images AS product_images,
                ${currentUserId ? `
                    EXISTS(
                        SELECT 1 FROM video_likes vl 
                        WHERE vl.video_id = v.id AND vl.user_id = $3
                    ) AS is_liked
                ` : 'FALSE AS is_liked'}
            FROM video_sales v
            JOIN users u ON v.user_id = u.id
            LEFT JOIN products p ON v.product_id = p.id
            WHERE v.status = 'active'
            ORDER BY v.created_at DESC
            LIMIT $1 OFFSET $2
        `;

        const params = currentUserId ? [limit, offset, currentUserId] : [limit, offset];
        const result = await pool.query(query, params);
        return result.rows;
    }

    /**
     * Créer une vidéo de vente
     */
    async createVideo(userId, videoUrl, thumbnailUrl, productId, title, description) {
        // Vérification limite : 3 vidéos/mois pour non-certifiés
        const userCheck = await pool.query(
            'SELECT has_certified_shop FROM users WHERE id = $1',
            [userId]
        );
        const isCertified = userCheck.rows[0]?.has_certified_shop;

        if (!isCertified) {
            const countResult = await pool.query(
                `SELECT COUNT(*) AS cnt FROM video_sales 
                 WHERE user_id = $1 
                 AND created_at >= date_trunc('month', NOW())
                 AND status != 'deleted'`,
                [userId]
            );
            const monthCount = parseInt(countResult.rows[0].cnt);
            if (monthCount >= 3) {
                throw new Error('LIMIT_REACHED');
            }
        }

        const result = await pool.query(
            `INSERT INTO video_sales (user_id, product_id, video_url, thumbnail_url, title, description)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING *`,
            [userId, productId || null, videoUrl, thumbnailUrl || null, title || null, description || null]
        );
        return result.rows[0];
    }

    /**
     * Incrémenter le compteur de vues (1 seule fois par user)
     */
    async incrementView(videoId, userId) {
        try {
            const result = await pool.query(
                `INSERT INTO video_views (video_id, user_id)
                 VALUES ($1, $2)
                 ON CONFLICT (video_id, user_id) DO NOTHING
                 RETURNING id`,
                [videoId, userId]
            );

            if (result.rows.length > 0) {
                await pool.query(
                    'UPDATE video_sales SET views_count = views_count + 1 WHERE id = $1',
                    [videoId]
                );
                return { newView: true };
            }
            return { newView: false };
        } catch (err) {
            console.error('❌ Erreur increment view:', err.message);
            return { newView: false };
        }
    }

    /**
     * Toggle like (like ou unlike)
     */
    async toggleLike(videoId, userId) {
        const existing = await pool.query(
            'SELECT id FROM video_likes WHERE video_id = $1 AND user_id = $2',
            [videoId, userId]
        );

        if (existing.rows.length > 0) {
            await pool.query(
                'DELETE FROM video_likes WHERE video_id = $1 AND user_id = $2',
                [videoId, userId]
            );
            await pool.query(
                'UPDATE video_sales SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = $1',
                [videoId]
            );
            return { liked: false };
        } else {
            await pool.query(
                'INSERT INTO video_likes (video_id, user_id) VALUES ($1, $2)',
                [videoId, userId]
            );
            await pool.query(
                'UPDATE video_sales SET likes_count = likes_count + 1 WHERE id = $1',
                [videoId]
            );
            return { liked: true };
        }
    }

    /**
     * Supprimer une vidéo (soft delete, propriétaire uniquement)
     */
    async deleteVideo(videoId, userId) {
        const result = await pool.query(
            `UPDATE video_sales SET status = 'deleted', updated_at = NOW()
             WHERE id = $1 AND user_id = $2
             RETURNING id`,
            [videoId, userId]
        );
        if (result.rows.length === 0) {
            throw new Error('NOT_FOUND');
        }
        return { success: true };
    }

    /**
     * Récupérer les vidéos d'un utilisateur
     */
    async getUserVideos(userId) {
        const result = await pool.query(
            `SELECT id, video_url, thumbnail_url, title, views_count, likes_count, 
                    product_id, status, created_at
             FROM video_sales 
             WHERE user_id = $1 AND status != 'deleted'
             ORDER BY created_at DESC`,
            [userId]
        );
        return result.rows;
    }
}

module.exports = new VideoSalesService();
