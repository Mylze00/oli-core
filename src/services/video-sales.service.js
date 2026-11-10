/**
 * Service Video Sales — Live Shopping MVP
 * Gère les vidéos de vente pré-enregistrées
 */
const pool = require('../config/db');

const COMMENT_MAX_LENGTH = 500;
const CLOUDINARY_VIDEO_PATH = '/video/upload/';
// Au-delà, Cloudinary ne transforme plus une vidéo à la volée sur l'offre gratuite
const MAX_TRANSFORMED_VIDEO_BYTES = 40 * 1024 * 1024;
const MAX_VIDEO_SECONDS = 600;
const COMMENT_SORTS = {
    recent: 'c.created_at DESC, c.id DESC',
    top: 'likes_count DESC, c.created_at DESC, c.id DESC',
};
const MAX_REPLIES = 100;
const REPORT_REASONS = ['spam', 'arnaque', 'contenu_choquant', 'contrefacon', 'autre'];

/** Commentaire complet tel que vu par l'utilisateur placé dans le paramètre SQL indiqué. */
function commentSelect(viewerParam) {
    return `
        SELECT c.id, c.video_id, c.user_id, c.parent_id, c.content, c.image_url, c.created_at,
               u.name AS user_name, u.avatar_url AS user_avatar,
               c.user_id = v.user_id AS is_creator,
               (SELECT COUNT(*)::int FROM video_comment_reactions r
                WHERE r.comment_id = c.id AND r.value = 1) AS likes_count,
               COALESCE((SELECT r.value::int FROM video_comment_reactions r
                         WHERE r.comment_id = c.id AND r.user_id = ${viewerParam}), 0) AS my_reaction,
               EXISTS(SELECT 1 FROM video_comment_reactions r
                      WHERE r.comment_id = c.id AND r.user_id = v.user_id AND r.value = 1) AS creator_liked,
               (SELECT COUNT(*)::int FROM video_comments reply
                WHERE reply.parent_id = c.id AND reply.status = 'active') AS replies_count
        FROM video_comments c
        JOIN users u ON u.id = c.user_id
        JOIN video_sales v ON v.id = c.video_id
    `;
}

class VideoSalesService {

    /**
     * Construit l'URL diffusée : qualité optimisée par Cloudinary et, si demandé,
     * son de la vidéo remplacé par le fichier audio envoyé.
     *
     * @param {{videoUrl: string, videoBytes: number, audioPublicId?: string, durationSeconds?: string|number}} media
     * @throws {Error} AUDIO_UNAVAILABLE sans Cloudinary, AUDIO_VIDEO_TOO_LARGE au-delà de 40 Mo
     */
    buildPublishedVideoUrl({ videoUrl, videoBytes, audioPublicId, durationSeconds }) {
        if (!videoUrl.includes(CLOUDINARY_VIDEO_PATH)) {
            if (audioPublicId) throw new Error('AUDIO_UNAVAILABLE');
            return videoUrl;
        }
        if (videoBytes > MAX_TRANSFORMED_VIDEO_BYTES) {
            if (audioPublicId) throw new Error('AUDIO_VIDEO_TOO_LARGE');
            return videoUrl;
        }

        const steps = [];
        if (audioPublicId) {
            const duration = parseInt(durationSeconds, 10);
            const isValidDuration = duration > 0 && duration <= MAX_VIDEO_SECONDS;
            steps.push('ac_none', `l_audio:${audioPublicId.replace(/\//g, ':')}`);
            // La piste ajoutée est coupée à la longueur de la vidéo
            if (isValidDuration) steps.push(`du_${duration}`);
            steps.push('fl_layer_apply');
        }
        steps.push('q_auto');

        return videoUrl.replace(CLOUDINARY_VIDEO_PATH, `${CLOUDINARY_VIDEO_PATH}${steps.join('/')}/`);
    }

    /**
     * Vérifie qu'une vidéo est publiée et retourne son propriétaire.
     * @throws {Error} NOT_FOUND si la vidéo est absente, supprimée ou retirée par la modération.
     */
    async _getActiveVideoOwner(videoId) {
        const result = await pool.query(
            `SELECT user_id FROM video_sales WHERE id = $1 AND status = 'active'`,
            [videoId]
        );
        if (result.rows.length === 0) {
            throw new Error('NOT_FOUND');
        }
        return result.rows[0].user_id;
    }

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
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_comments (
                    id SERIAL PRIMARY KEY,
                    video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    content VARCHAR(${COMMENT_MAX_LENGTH}) NOT NULL,
                    status VARCHAR(20) NOT NULL DEFAULT 'active',
                    created_at TIMESTAMPTZ DEFAULT NOW()
                )
            `);
            await pool.query(`
                ALTER TABLE video_comments
                ADD COLUMN IF NOT EXISTS parent_id INTEGER REFERENCES video_comments(id) ON DELETE CASCADE,
                ADD COLUMN IF NOT EXISTS image_url TEXT
            `);
            await pool.query(`
                CREATE INDEX IF NOT EXISTS idx_video_comments_parent ON video_comments(parent_id)
            `);
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_comment_reactions (
                    comment_id INTEGER NOT NULL REFERENCES video_comments(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    value SMALLINT NOT NULL CHECK (value IN (1, -1)),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    PRIMARY KEY (comment_id, user_id)
                )
            `);
            await pool.query(`
                CREATE INDEX IF NOT EXISTS idx_video_comments_video
                ON video_comments(video_id, created_at DESC)
            `);
            await pool.query(`
                CREATE TABLE IF NOT EXISTS video_reports (
                    id SERIAL PRIMARY KEY,
                    video_id INTEGER NOT NULL REFERENCES video_sales(id) ON DELETE CASCADE,
                    reporter_id INTEGER NOT NULL REFERENCES users(id),
                    reason VARCHAR(30) NOT NULL,
                    details TEXT,
                    status VARCHAR(20) NOT NULL DEFAULT 'pending',
                    reviewed_by INTEGER REFERENCES users(id),
                    reviewed_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    UNIQUE(video_id, reporter_id)
                )
            `);
            await pool.query(`
                CREATE INDEX IF NOT EXISTS idx_video_reports_status
                ON video_reports(status, created_at DESC)
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
                p.id AS product_id, v.created_at,
                u.id AS seller_id, u.name AS seller_name, u.avatar_url AS seller_avatar,
                u.has_certified_shop AS seller_certified,
                p.name AS product_name, p.price AS product_price,
                p.images AS product_images,
                ps.name AS product_seller_name,
                (
                    SELECT COUNT(*)::int FROM video_comments vc
                    WHERE vc.video_id = v.id AND vc.status = 'active'
                ) AS comments_count,
                ${currentUserId ? `
                    EXISTS(
                        SELECT 1 FROM video_likes vl 
                        WHERE vl.video_id = v.id AND vl.user_id = $3
                    ) AS is_liked
                ` : 'FALSE AS is_liked'}
            FROM video_sales v
            JOIN users u ON v.user_id = u.id
            LEFT JOIN products p ON v.product_id = p.id AND p.status = 'active'
            LEFT JOIN users ps ON p.seller_id = ps.id
            WHERE v.status = 'active'
            ${currentUserId ? `
                AND NOT EXISTS(
                    SELECT 1 FROM video_reports vr
                    WHERE vr.video_id = v.id AND vr.reporter_id = $3
                )
            ` : ''}
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
        // N'importe quel produit actif peut être lié (affiliation entre vendeurs)
        if (productId) {
            const parsedProductId = parseInt(productId, 10);
            const productCheck = Number.isInteger(parsedProductId)
                ? await pool.query(
                    `SELECT 1 FROM products WHERE id = $1 AND status = 'active'`,
                    [parsedProductId]
                )
                : { rows: [] };
            if (productCheck.rows.length === 0) {
                throw new Error('INVALID_PRODUCT');
            }
        }

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
        // Une vidéo retirée ou supprimée ne doit plus générer de récompense
        await this._getActiveVideoOwner(videoId);

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

            // -- MONÉTISATION : 1 FC PAR J'AIME --
            try {
                // Trouver le propriétaire de la vidéo
                const ownerRes = await pool.query('SELECT user_id FROM video_sales WHERE id = $1', [videoId]);
                if (ownerRes.rows.length > 0) {
                    const ownerId = ownerRes.rows[0].user_id;
                    // Ne pas se récompenser soi-même
                    if (ownerId != userId) {
                        // [FIN C1] Une seule récompense par (compte, vidéo, sans plafond journalier) : pas de récompense
                        // en cas de unlike puis de nouveau like.
                        const alreadyRewarded = await pool.query(
                            `SELECT 1 FROM wallet_transactions
                             WHERE user_id = $1 AND type = 'reward' AND starts_with(reference, $2)
                             LIMIT 1`,
                            [ownerId, `LIKE_${videoId}_${userId}_`]
                        );
                        // Pas de plafond : décision métier. Seul l'anti-doublon ci-dessus s'applique.
                        if (alreadyRewarded.rows.length === 0) {
                            const walletRepository = require('../repositories/wallet.repository');
                            await walletRepository.performDeposit(ownerId, 1, {
                                type: 'reward',
                                provider: 'LIVE_SHOPPING',
                                reference: `LIKE_${videoId}_${userId}_${Date.now()}`,
                                description: `Récompense de 1 FC pour un J'aime sur votre vidéo`
                            });
                        }
                    }
                }
            } catch (err) {
                console.error('⚠️ Erreur monétisation like:', err.message);
            }

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

    /**
     * Commentaires principaux d'une vidéo, paginés
     * @param {{page?: number, limit?: number, sort?: 'recent'|'top'}} options
     */
    async getComments(videoId, viewerId, { page = 1, limit = 20, sort = 'recent' } = {}) {
        const result = await pool.query(
            `${commentSelect('$2')}
             WHERE c.video_id = $1 AND c.status = 'active' AND c.parent_id IS NULL
             ORDER BY ${COMMENT_SORTS[sort] || COMMENT_SORTS.recent}
             LIMIT $3 OFFSET $4`,
            [videoId, viewerId, limit, (page - 1) * limit]
        );
        return result.rows;
    }

    /**
     * Réponses à un commentaire, dans l'ordre de la conversation
     */
    async getReplies(videoId, parentId, viewerId) {
        const result = await pool.query(
            `${commentSelect('$3')}
             WHERE c.video_id = $1 AND c.parent_id = $2 AND c.status = 'active'
             ORDER BY c.created_at ASC, c.id ASC
             LIMIT ${MAX_REPLIES}`,
            [videoId, parentId, viewerId]
        );
        return result.rows;
    }

    async _getCommentForViewer(commentId, viewerId) {
        const result = await pool.query(
            `${commentSelect('$2')} WHERE c.id = $1`,
            [commentId, viewerId]
        );
        return result.rows[0];
    }

    /**
     * Rattache une réponse au commentaire principal : la conversation garde un seul niveau.
     * @throws {Error} INVALID_PARENT si le commentaire visé n'existe pas sur cette vidéo
     */
    async _resolveParentId(videoId, parentId) {
        if (!parentId) return null;
        if (!/^\d+$/.test(String(parentId))) {
            throw new Error('INVALID_PARENT');
        }
        const result = await pool.query(
            `SELECT id, parent_id FROM video_comments
             WHERE id = $1 AND video_id = $2 AND status = 'active'`,
            [parentId, videoId]
        );
        if (result.rows.length === 0) {
            throw new Error('INVALID_PARENT');
        }
        return result.rows[0].parent_id || result.rows[0].id;
    }

    /**
     * Ajoute un commentaire, une réponse ou une image sur une vidéo publiée
     * @throws {Error} INVALID_COMMENT si le commentaire est vide ou trop long
     */
    async addComment(videoId, userId, rawContent, { parentId = null, imageUrl = null } = {}) {
        const content = typeof rawContent === 'string' ? rawContent.trim() : '';
        if ((!content && !imageUrl) || content.length > COMMENT_MAX_LENGTH) {
            throw new Error('INVALID_COMMENT');
        }
        await this._getActiveVideoOwner(videoId);
        const rootParentId = await this._resolveParentId(videoId, parentId);

        const inserted = await pool.query(
            `INSERT INTO video_comments (video_id, user_id, content, parent_id, image_url)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id`,
            [videoId, userId, content, rootParentId, imageUrl]
        );
        return this._getCommentForViewer(inserted.rows[0].id, userId);
    }

    /**
     * Enregistre la réaction d'un utilisateur à un commentaire
     * @param {1|-1|0} value - j'aime, je n'aime pas, ou retrait de la réaction
     * @throws {Error} INVALID_REACTION si la valeur est inconnue, NOT_FOUND si le commentaire est absent
     */
    async reactToComment(videoId, commentId, userId, value) {
        if (![1, -1, 0].includes(value)) {
            throw new Error('INVALID_REACTION');
        }
        const comment = await pool.query(
            `SELECT 1 FROM video_comments c
             JOIN video_sales v ON v.id = c.video_id
             WHERE c.id = $1 AND c.video_id = $2 AND c.status = 'active' AND v.status = 'active'`,
            [commentId, videoId]
        );
        if (comment.rows.length === 0) {
            throw new Error('NOT_FOUND');
        }

        if (value === 0) {
            await pool.query(
                'DELETE FROM video_comment_reactions WHERE comment_id = $1 AND user_id = $2',
                [commentId, userId]
            );
        } else {
            await pool.query(
                `INSERT INTO video_comment_reactions (comment_id, user_id, value)
                 VALUES ($1, $2, $3)
                 ON CONFLICT (comment_id, user_id) DO UPDATE SET value = EXCLUDED.value`,
                [commentId, userId, value]
            );
        }
        return this._getCommentForViewer(commentId, userId);
    }

    /**
     * Masque un commentaire et ses réponses (auteur du commentaire ou propriétaire de la vidéo)
     * @returns {Promise<{deleted: number}>} nombre de commentaires masqués
     */
    async deleteComment(videoId, commentId, userId) {
        const result = await pool.query(
            `WITH target AS (
                UPDATE video_comments c SET status = 'deleted'
                FROM video_sales v
                WHERE c.id = $1 AND c.video_id = $2 AND v.id = c.video_id
                  AND c.status = 'active'
                  AND (c.user_id = $3 OR v.user_id = $3)
                RETURNING c.id
             ), replies AS (
                UPDATE video_comments SET status = 'deleted'
                WHERE parent_id IN (SELECT id FROM target) AND status = 'active'
                RETURNING id
             )
             SELECT (SELECT COUNT(*) FROM target)::int AS comments,
                    (SELECT COUNT(*) FROM replies)::int AS replies`,
            [commentId, videoId, userId]
        );
        const { comments, replies } = result.rows[0];
        if (comments === 0) {
            throw new Error('NOT_FOUND');
        }
        return { deleted: comments + replies };
    }

    /**
     * Signale une vidéo à la modération (un signalement par compte et par vidéo)
     * @throws {Error} INVALID_REASON si le motif est inconnu, OWN_VIDEO pour sa propre vidéo
     */
    async reportVideo(videoId, reporterId, reason, details) {
        if (!REPORT_REASONS.includes(reason)) {
            throw new Error('INVALID_REASON');
        }
        const ownerId = await this._getActiveVideoOwner(videoId);
        if (String(ownerId) === String(reporterId)) {
            throw new Error('OWN_VIDEO');
        }
        await pool.query(
            `INSERT INTO video_reports (video_id, reporter_id, reason, details)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (video_id, reporter_id) DO NOTHING`,
            [videoId, reporterId, reason, typeof details === 'string' ? details.trim().slice(0, 1000) || null : null]
        );
        return { reported: true };
    }

    /**
     * Liste des vidéos pour la modération
     * @param {'pending'|'removed'|'all'} filter
     */
    async listForModeration(filter = 'pending', limit = 50, offset = 0) {
        const statusClause = filter === 'removed' ? `AND v.status = 'removed'` : '';
        const havingClause = filter === 'pending'
            ? `HAVING COUNT(r.id) FILTER (WHERE r.status = 'pending') > 0`
            : '';

        const result = await pool.query(
            `SELECT v.id, v.video_url, v.thumbnail_url, v.title, v.description, v.status,
                    v.views_count, v.likes_count, v.created_at,
                    u.id AS seller_id, u.name AS seller_name, u.phone AS seller_phone,
                    COUNT(r.id) FILTER (WHERE r.status = 'pending')::int AS pending_reports,
                    COALESCE(
                        json_agg(
                            json_build_object(
                                'id', r.id, 'reason', r.reason, 'details', r.details,
                                'status', r.status, 'created_at', r.created_at,
                                'reporter_name', ru.name
                            ) ORDER BY r.created_at DESC
                        ) FILTER (WHERE r.id IS NOT NULL),
                        '[]'
                    ) AS reports
             FROM video_sales v
             JOIN users u ON u.id = v.user_id
             LEFT JOIN video_reports r ON r.video_id = v.id
             LEFT JOIN users ru ON ru.id = r.reporter_id
             WHERE v.status <> 'deleted' ${statusClause}
             GROUP BY v.id, u.id
             ${havingClause}
             ORDER BY pending_reports DESC, v.created_at DESC
             LIMIT $1 OFFSET $2`,
            [limit, offset]
        );
        return result.rows;
    }

    /**
     * Applique une décision de modération sur une vidéo
     * @param {'remove'|'restore'|'dismiss'} action
     * @throws {Error} NOT_FOUND si la vidéo n'est pas dans un état compatible avec l'action
     */
    async moderateVideo(videoId, adminId, action) {
        const REVIEW_REPORTS = `
            UPDATE video_reports
            SET status = $3, reviewed_by = $2, reviewed_at = NOW()
            WHERE video_id IN (SELECT id FROM target) AND status = 'pending'
        `;
        const queries = {
            remove: {
                sql: `WITH target AS (
                        UPDATE video_sales SET status = 'removed', updated_at = NOW()
                        WHERE id = $1 AND status = 'active'
                        RETURNING id
                      ), reviewed AS (${REVIEW_REPORTS})
                      SELECT id FROM target`,
                params: [videoId, adminId, 'actioned'],
            },
            dismiss: {
                sql: `WITH target AS (
                        SELECT id FROM video_sales WHERE id = $1 AND status <> 'deleted'
                      ), reviewed AS (${REVIEW_REPORTS})
                      SELECT id FROM target`,
                params: [videoId, adminId, 'dismissed'],
            },
            restore: {
                sql: `UPDATE video_sales SET status = 'active', updated_at = NOW()
                      WHERE id = $1 AND status = 'removed'
                      RETURNING id`,
                params: [videoId],
            },
        };

        const query = queries[action];
        const result = await pool.query(query.sql, query.params);
        if (result.rows.length === 0) {
            throw new Error('NOT_FOUND');
        }
        return { success: true };
    }
}

module.exports = new VideoSalesService();
