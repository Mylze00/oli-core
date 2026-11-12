const db = require('../config/db');

// ── Tables du Fil créées au démarrage (republications, enregistrements, masqués,
//    signalements) et compteur de vues ─────────────────────────────────────────
db.query(`
    ALTER TABLE feed_posts ADD COLUMN IF NOT EXISTS views_count INTEGER NOT NULL DEFAULT 0;
    CREATE TABLE IF NOT EXISTS feed_reposts (
        id SERIAL PRIMARY KEY,
        post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (post_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS feed_bookmarks (
        id SERIAL PRIMARY KEY,
        post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (post_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS feed_hidden_posts (
        post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (post_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS feed_reports (
        id SERIAL PRIMARY KEY,
        post_id INTEGER NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reason VARCHAR(20) NOT NULL,
        details TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (post_id, user_id)
    );
`).catch((e) => console.error('❌ Migration fil (feed):', e.message));

/** Champs d'un post : auteur, compteurs et état pour l'utilisateur ($1 = son id, 0 si anonyme). */
const POST_FIELDS = `
    p.id, p.content, p.media_url, p.media_type, p.created_at, p.views_count,
    p.user_id AS author_id,
    u.name AS author_name,
    u.avatar_url AS author_avatar,
    u.id_oli AS author_oli_id,
    COALESCE(u.is_verified, FALSE) AS author_verified,
    (SELECT COUNT(*) FROM feed_likes WHERE post_id = p.id) AS likes_count,
    (SELECT COUNT(*) FROM feed_comments WHERE post_id = p.id) AS comments_count,
    (SELECT COUNT(*) FROM feed_reposts WHERE post_id = p.id) AS reposts_count,
    (SELECT COUNT(*) FROM feed_bookmarks WHERE post_id = p.id) AS bookmarks_count,
    EXISTS(SELECT 1 FROM feed_likes WHERE post_id = p.id AND user_id = $1) AS is_liked_by_me,
    EXISTS(SELECT 1 FROM feed_reposts WHERE post_id = p.id AND user_id = $1) AS is_reposted_by_me,
    EXISTS(SELECT 1 FROM feed_bookmarks WHERE post_id = p.id AND user_id = $1) AS is_bookmarked_by_me,
    (p.user_id = $1) AS is_mine
`;

// Récupérer le fil d'actualité (avec pagination)
exports.getFeed = async (req, res) => {
    try {
        const userId = req.user?.id || 0;
        const limit = Math.min(parseInt(req.query.limit) || 20, 50);
        const cursor = req.query.cursor; // ISO timestamp string

        const params = [userId, limit];
        // Les posts masqués ou signalés par l'utilisateur ne lui sont plus montrés
        let where = `
            WHERE NOT EXISTS (SELECT 1 FROM feed_hidden_posts h WHERE h.post_id = p.id AND h.user_id = $1)
              AND NOT EXISTS (SELECT 1 FROM feed_reports r WHERE r.post_id = p.id AND r.user_id = $1)`;
        if (cursor) {
            params.push(cursor);
            where += ` AND p.created_at < $3`;
        }

        const result = await db.query(
            `SELECT ${POST_FIELDS}
             FROM feed_posts p
             JOIN users u ON p.user_id = u.id
             ${where}
             ORDER BY p.created_at DESC, p.id DESC
             LIMIT $2`,
            params
        );

        const nextCursor = result.rows.length === limit ? result.rows[result.rows.length - 1].created_at : null;
        res.json({ success: true, posts: result.rows, nextCursor });
    } catch (error) {
        console.error('Erreur getFeed:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération du fil d\'actualité' });
    }
};

// Détail d'un post (page « Post »)
exports.getPost = async (req, res) => {
    try {
        const userId = req.user?.id || 0;
        const result = await db.query(
            `SELECT ${POST_FIELDS} FROM feed_posts p JOIN users u ON p.user_id = u.id WHERE p.id = $2`,
            [userId, req.params.id]
        );
        if (!result.rows[0]) return res.status(404).json({ error: 'Publication introuvable' });
        res.json({ success: true, post: result.rows[0] });
    } catch (error) {
        console.error('Erreur getPost:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération de la publication' });
    }
};

// Vue d'un post (ouverture de la page « Post »)
exports.recordView = async (req, res) => {
    try {
        const result = await db.query(
            'UPDATE feed_posts SET views_count = views_count + 1 WHERE id = $1 RETURNING views_count',
            [req.params.id]
        );
        res.json({ success: true, views_count: result.rows[0]?.views_count ?? 0 });
    } catch (error) {
        console.error('Erreur recordView:', error);
        res.status(500).json({ error: 'Erreur' });
    }
};

/** Bascule une action (republier, enregistrer) et renvoie le nouvel état et le compteur. */
async function toggleAction(table, req, res, stateKey) {
    try {
        const userId = req.user.id;
        const postId = req.params.id;
        const removed = await db.query(`DELETE FROM ${table} WHERE post_id = $1 AND user_id = $2 RETURNING id`, [postId, userId]);
        if (removed.rows.length === 0) {
            await db.query(`INSERT INTO ${table} (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [postId, userId]);
        }
        const count = await db.query(`SELECT COUNT(*)::int AS n FROM ${table} WHERE post_id = $1`, [postId]);
        res.json({ success: true, [stateKey]: removed.rows.length === 0, count: count.rows[0].n });
    } catch (error) {
        console.error(`Erreur ${table}:`, error);
        res.status(500).json({ error: 'Erreur' });
    }
}

exports.toggleRepost = (req, res) => toggleAction('feed_reposts', req, res, 'reposted');
exports.toggleBookmark = (req, res) => toggleAction('feed_bookmarks', req, res, 'bookmarked');

// Masquer un post (il disparaît du fil de l'utilisateur)
exports.hidePost = async (req, res) => {
    try {
        await db.query(
            'INSERT INTO feed_hidden_posts (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [req.params.id, req.user.id]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Erreur hidePost:', error);
        res.status(500).json({ error: 'Erreur' });
    }
};

// Signaler un post ou le marquer comme spam (il disparaît aussi du fil du signaleur)
exports.reportPost = async (req, res) => {
    try {
        const reason = req.body?.reason === 'spam' ? 'spam' : 'report';
        const details = typeof req.body?.details === 'string' ? req.body.details.slice(0, 500) : null;
        await db.query(
            `INSERT INTO feed_reports (post_id, user_id, reason, details) VALUES ($1, $2, $3, $4)
             ON CONFLICT (post_id, user_id) DO UPDATE SET reason = EXCLUDED.reason, details = EXCLUDED.details`,
            [req.params.id, req.user.id, reason, details]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Erreur reportPost:', error);
        res.status(500).json({ error: 'Erreur' });
    }
};

// Supprimer son propre post
exports.deletePost = async (req, res) => {
    try {
        const result = await db.query('DELETE FROM feed_posts WHERE id = $1 AND user_id = $2 RETURNING id', [
            req.params.id,
            req.user.id,
        ]);
        if (!result.rows[0]) return res.status(403).json({ error: 'Seul l\'auteur peut supprimer cette publication' });
        res.json({ success: true });
    } catch (error) {
        console.error('Erreur deletePost:', error);
        res.status(500).json({ error: 'Erreur' });
    }
};

// Interactions avec un post (réservé à l'auteur) : compteurs et dernières personnes
exports.getInteractions = async (req, res) => {
    try {
        const postId = req.params.id;
        const owner = await db.query('SELECT user_id, views_count FROM feed_posts WHERE id = $1', [postId]);
        if (!owner.rows[0]) return res.status(404).json({ error: 'Publication introuvable' });
        if (Number(owner.rows[0].user_id) !== Number(req.user.id)) {
            return res.status(403).json({ error: 'Réservé à l\'auteur de la publication' });
        }
        const people = (table) => db.query(
            `SELECT u.id, u.name, u.avatar_url, t.created_at FROM ${table} t JOIN users u ON u.id = t.user_id
             WHERE t.post_id = $1 ORDER BY t.created_at DESC LIMIT 30`,
            [postId]
        );
        const [likes, reposts, counts] = await Promise.all([
            people('feed_likes'),
            people('feed_reposts'),
            db.query(
                `SELECT
                    (SELECT COUNT(*)::int FROM feed_likes WHERE post_id = $1) AS likes,
                    (SELECT COUNT(*)::int FROM feed_comments WHERE post_id = $1) AS comments,
                    (SELECT COUNT(*)::int FROM feed_reposts WHERE post_id = $1) AS reposts,
                    (SELECT COUNT(*)::int FROM feed_bookmarks WHERE post_id = $1) AS bookmarks`,
                [postId]
            ),
        ]);
        res.json({
            success: true,
            views: owner.rows[0].views_count,
            ...counts.rows[0],
            liked_by: likes.rows,
            reposted_by: reposts.rows,
        });
    } catch (error) {
        console.error('Erreur getInteractions:', error);
        res.status(500).json({ error: 'Erreur' });
    }
};

// Créer une nouvelle publication
exports.createPost = async (req, res) => {
    try {
        const userId = req.user.id;
        let { content, media_url, media_type } = req.body;

        // Si un fichier a été uploadé (via Cloudinary ou local)
        if (req.file) {
            // Dans Cloudinary, l'URL est dans path. En local, c'est filename
            media_url = req.file.path || `/uploads/${req.file.filename}`;
            
            // Déduction du type de média depuis le mimetype
            if (req.file.mimetype.startsWith('video/')) {
                media_type = 'video';
            } else if (req.file.mimetype.startsWith('image/')) {
                media_type = 'image';
            }
        }

        if (!content && !media_url) {
            return res.status(400).json({ error: 'La publication doit contenir du texte ou un média' });
        }

        const query = `
            INSERT INTO feed_posts (user_id, content, media_url, media_type)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `;
        
        const result = await db.query(query, [
            userId, 
            content || null, 
            media_url || null, 
            media_type || 'text'
        ]);

        res.status(201).json({
            success: true,
            post: result.rows[0]
        });
    } catch (error) {
        console.error('Erreur createPost:', error);
        res.status(500).json({ error: 'Erreur lors de la création de la publication' });
    }
};

// Liker ou unliker une publication
exports.toggleLike = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.id;

        // Vérifier si le like existe déjà
        const checkQuery = `SELECT id FROM feed_likes WHERE post_id = $1 AND user_id = $2`;
        const checkResult = await db.query(checkQuery, [postId, userId]);

        if (checkResult.rows.length > 0) {
            // S'il existe, on le retire (Unlike)
            await db.query(`DELETE FROM feed_likes WHERE post_id = $1 AND user_id = $2`, [postId, userId]);
            res.json({ success: true, liked: false });
        } else {
            // Sinon, on l'ajoute (Like)
            await db.query(`INSERT INTO feed_likes (post_id, user_id) VALUES ($1, $2)`, [postId, userId]);
            res.json({ success: true, liked: true });
        }
    } catch (error) {
        console.error('Erreur toggleLike:', error);
        res.status(500).json({ error: 'Erreur lors de l\'action sur le like' });
    }
};

// Récupérer les commentaires d'une publication
exports.getComments = async (req, res) => {
    try {
        const postId = req.params.id;
        
        const query = `
            SELECT 
                c.id, 
                c.content, 
                c.media_url,
                c.media_type,
                c.created_at,
                u.name AS author_name,
                u.avatar_url AS author_avatar
            FROM feed_comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.post_id = $1
            ORDER BY c.created_at ASC
        `;
        
        const result = await db.query(query, [postId]);
        
        res.json({
            success: true,
            comments: result.rows
        });
    } catch (error) {
        console.error('Erreur getComments:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération des commentaires' });
    }
};

// Ajouter un commentaire
exports.addComment = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.id;
        let { content, media_type } = req.body;
        let media_url = null;

        // Si un fichier a été uploadé (via Cloudinary ou local)
        if (req.file) {
            media_url = req.file.path || `/uploads/${req.file.filename}`;
            if (req.file.mimetype.startsWith('video/')) {
                media_type = 'video';
            } else if (req.file.mimetype.startsWith('image/')) {
                media_type = 'image';
            }
        }

        if ((!content || content.trim() === '') && !media_url) {
            return res.status(400).json({ error: 'Le commentaire ne peut pas être vide' });
        }

        const query = `
            INSERT INTO feed_comments (post_id, user_id, content, media_url, media_type)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, content, media_url, media_type, created_at
        `;
        
        const result = await db.query(query, [postId, userId, content ? content.trim() : null, media_url, media_type || 'text']);
        
        res.status(201).json({
            success: true,
            comment: result.rows[0]
        });
    } catch (error) {
        console.error('Erreur addComment:', error);
        res.status(500).json({ error: 'Erreur lors de l\'ajout du commentaire' });
    }
};
