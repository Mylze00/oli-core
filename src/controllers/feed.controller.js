const db = require('../config/db');

// Récupérer le fil d'actualité (avec pagination)
exports.getFeed = async (req, res) => {
    try {
        const userId = req.user?.id;
        const limit = parseInt(req.query.limit) || 20;
        const cursor = req.query.cursor; // ISO timestamp string

        let query = `
            SELECT 
                p.id, 
                p.content, 
                p.media_url, 
                p.media_type, 
                p.created_at,
                u.name AS author_name,
                u.avatar_url AS author_avatar,
                (SELECT COUNT(*) FROM feed_likes WHERE post_id = p.id) AS likes_count,
                (SELECT COUNT(*) FROM feed_comments WHERE post_id = p.id) AS comments_count,
                EXISTS(SELECT 1 FROM feed_likes WHERE post_id = p.id AND user_id = $1) AS is_liked_by_me
            FROM feed_posts p
            JOIN users u ON p.user_id = u.id
        `;

        const params = [userId || 0, limit];
        
        if (cursor) {
            query += ` WHERE p.created_at < $3`;
            params.push(cursor);
        }

        query += ` ORDER BY p.created_at DESC LIMIT $2`;

        const result = await db.query(query, params);

        let nextCursor = null;
        if (result.rows.length === limit) {
            nextCursor = result.rows[result.rows.length - 1].created_at;
        }

        res.json({
            success: true,
            posts: result.rows,
            nextCursor
        });
    } catch (error) {
        console.error('Erreur getFeed:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération du fil d\'actualité' });
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
