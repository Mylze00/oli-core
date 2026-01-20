const pool = require('../config/db');
const { BASE_URL } = require('../config');

// --- HELPER FUNCTIONS ---
const formatProductImage = (row) => {
    let imgUrl = null;
    if (row.product_images_raw) {
        let imgs = Array.isArray(row.product_images_raw)
            ? row.product_images_raw
            : row.product_images_raw.replace(/[{}\"]/g, '').split(',');
        if (imgs.length > 0 && imgs[0]) {
            imgUrl = imgs[0].startsWith('http') ? imgs[0] : `${BASE_URL}/uploads/${imgs[0]}`;
        }
    }
    return imgUrl;
};

/**
 * Upload d'un fichier chat
 */
exports.uploadFile = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: "Pas de fichier" });
    }

    const fileUrl = `${BASE_URL}/uploads/${req.file.filename}`;
    const fileType = req.file.mimetype.startsWith('image/') ? 'image' :
        req.file.mimetype.startsWith('audio/') ? 'audio' : 'file';

    res.json({ url: fileUrl, type: fileType });
};

/**
 * Envoyer un premier message (démarre conversation)
 */
exports.sendInitialMessage = async (req, res) => {
    const { recipientId, content, type = 'text', productId, metadata, conversationId: existingConvId } = req.body;
    const senderId = req.user.id;

    try {
        let conversationId = existingConvId;
        let friendshipStatus = 'pending';
        let requesterId = senderId;

        if (!conversationId) {
            const convCheck = await pool.query(`
                SELECT c.id FROM conversations c
                JOIN conversation_participants cp1 ON cp1.conversation_id = c.id AND cp1.user_id = $1
                JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id = $2
                WHERE c.product_id = $3 AND c.type = 'private' LIMIT 1
            `, [senderId, recipientId, productId]);

            if (convCheck.rows.length > 0) {
                conversationId = convCheck.rows[0].id;
                const fCheck = await pool.query(`SELECT status, requester_id FROM friendships WHERE (requester_id=$1 AND addressee_id=$2) OR (requester_id=$2 AND addressee_id=$1)`, [senderId, recipientId]);
                if (fCheck.rows.length > 0) {
                    friendshipStatus = fCheck.rows[0].status;
                    requesterId = fCheck.rows[0].requester_id;
                }
            } else {
                const newConv = await pool.query(
                    `INSERT INTO conversations (product_id, type, created_at, updated_at) VALUES ($1, 'private', NOW(), NOW()) RETURNING id`,
                    [productId]
                );
                conversationId = newConv.rows[0].id;

                await pool.query(`
                    INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
                    VALUES ($1, $2, NOW()), ($1, $3, NOW())
                `, [conversationId, senderId, recipientId]);

                await pool.query(`
                    INSERT INTO friendships (requester_id, addressee_id, status) 
                    VALUES ($1, $2, 'pending') ON CONFLICT (requester_id, addressee_id) DO NOTHING
                `, [senderId, recipientId]);
            }
        }

        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, metadata) 
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [conversationId, senderId, content, type, metadata ? JSON.stringify(metadata) : null]
        );

        const newMessage = msgResult.rows[0];
        const io = req.app.get('io');
        if (io) {
            const socketPayload = { ...newMessage, conversation_id: conversationId, friendship_status: friendshipStatus, requester_id: requesterId };
            io.to(`user_${recipientId}`).emit('new_message', socketPayload);
            io.to(`user_${recipientId}`).emit('new_request', { sender_id: senderId, conversation_id: conversationId });
            io.to(`user_${senderId}`).emit('new_message', socketPayload);
        }

        res.json({ success: true, message: newMessage, conversationId, friendship_status: friendshipStatus, requester_id: requesterId });
    } catch (err) {
        console.error("Erreur sendInitialMessage:", err);
        res.status(500).json({ error: "Erreur lors de l'envoi" });
    }
};

/**
 * Envoyer un message dans une conversation existante
 */
exports.sendMessage = async (req, res) => {
    const { conversationId, type, amount, replyToId, mediaUrl, mediaType } = req.body;
    let { content, recipientId, metadata } = req.body;
    const senderId = req.user.id;

    // Validation : Soit du contenu, soit un média est requis
    if (!conversationId || (!content && !mediaUrl)) {
        return res.status(400).json({ error: "conversationId et content (ou mediaUrl) requis" });
    }

    // Si c'est un message média sans texte, on met un texte par défaut
    if (!content && mediaUrl) {
        content = mediaType === 'image' ? '📷 Image' : '📎 Fichier';
    }

    // Enrichissement des métadonnées avec les infos média
    let messageMetadata = metadata || {};
    if (typeof messageMetadata === 'string') {
        try { messageMetadata = JSON.parse(messageMetadata); } catch (e) { }
    }

    if (mediaUrl) {
        messageMetadata.mediaUrl = mediaUrl;
        messageMetadata.mediaType = mediaType || 'file';
    }

    try {
        if (!recipientId) {
            const partRes = await pool.query(
                "SELECT user_id FROM conversation_participants WHERE conversation_id = $1 AND user_id != $2",
                [conversationId, senderId]
            );
            if (partRes.rows.length > 0) recipientId = partRes.rows[0].user_id;
        }

        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, amount, reply_to_id, metadata) 
             VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
            [
                conversationId,
                senderId,
                content,
                type || (mediaUrl ? 'media' : 'text'),
                amount,
                replyToId,
                JSON.stringify(messageMetadata)
            ]
        );

        const newMessage = msgResult.rows[0];
        const io = req.app.get('io');
        if (io) {
            const socketPayload = { ...newMessage, conversation_id: conversationId, sender_id: senderId };
            io.to(`user_${recipientId}`).emit('new_message', socketPayload);
            io.to(`user_${senderId}`).emit('new_message', socketPayload);
        }

        res.json({ success: true, message: newMessage });
    } catch (err) {
        console.error("Erreur sendMessage:", err);
        res.status(500).json({ error: "Erreur lors de l'envoi" });
    }
};

/**
 * Lister les conversations
 */
exports.getConversations = async (req, res) => {
    const myId = req.user.id;
    try {
        const result = await pool.query(`
            SELECT c.id as conversation_id, u.name as other_name, u.avatar_url as other_avatar, u.id as other_id, u.phone as other_phone,
                m.content as last_message, m.type as last_message_type, m.created_at as last_time, m.sender_id as last_sender_id,
                p.id as product_id, p.name as product_name, p.price as product_price, p.images as product_images_raw,
                f.status as friendship_status, f.requester_id,
                (SELECT COUNT(*) FROM messages msg WHERE msg.conversation_id = c.id AND msg.is_read = false AND msg.sender_id != $1) as unread_count
            FROM conversation_participants cp
            JOIN conversations c ON cp.conversation_id = c.id
            JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
            JOIN users u ON cp2.user_id = u.id
            LEFT JOIN friendships f ON (f.requester_id = cp.user_id AND f.addressee_id = cp2.user_id) 
                                    OR (f.requester_id = cp2.user_id AND f.addressee_id = cp.user_id)
            LEFT JOIN products p ON c.product_id = p.id
            LEFT JOIN LATERAL (SELECT content, type, created_at, sender_id FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) m ON true
            WHERE cp.user_id = $1 ORDER BY m.created_at DESC NULLS LAST
        `, [myId]);

        const conversations = result.rows.map(row => ({
            ...row,
            product_image: formatProductImage(row),
            product_images_raw: undefined,
            unread_count: parseInt(row.unread_count) || 0
        }));
        res.json(conversations);
    } catch (err) {
        console.error("Erreur getConversations:", err);
        res.status(500).json({ error: "Erreur" });
    }
};

/**
 * Récupérer les messages d'une conversation
 */
exports.getMessages = async (req, res) => {
    const myId = req.user.id;
    const { otherUserId } = req.params;
    const { productId, limit = 50, cursor } = req.query;

    try {
        let conversationFilter = "";
        const params = [myId, otherUserId];
        let paramIndex = 3;

        if (productId) {
            conversationFilter = `AND c.product_id = $${paramIndex}`;
            params.push(productId);
            paramIndex++;
        }

        let cursorCondition = "";
        if (cursor) {
            cursorCondition = `AND m.id < $${paramIndex}`;
            params.push(parseInt(cursor));
            paramIndex++;
        }

        params.push(parseInt(limit));

        const result = await pool.query(`
            SELECT m.*, u.name as sender_name, u.phone as sender_phone, u.avatar_url as sender_avatar,
                c.product_id, c.id as conversation_id, parent.content as reply_to_content, parent.sender_id as reply_to_sender,
                f.status as friendship_status, f.requester_id
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            JOIN conversations c ON m.conversation_id = c.id
            LEFT JOIN messages parent ON m.reply_to_id = parent.id
            LEFT JOIN friendships f ON (f.requester_id = $1 AND f.addressee_id = $2) OR (f.requester_id = $2 AND f.addressee_id = $1)
            WHERE m.conversation_id IN (
                SELECT cp1.conversation_id FROM conversation_participants cp1
                JOIN conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
                WHERE cp1.user_id = $1 AND cp2.user_id = $2 ${conversationFilter}
            )
            ${cursorCondition} ORDER BY m.created_at DESC LIMIT $${paramIndex}
        `, params);

        if (result.rows.length > 0) {
            const convId = result.rows[0].conversation_id;
            await pool.query("UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id = $2 AND is_read = false", [convId, otherUserId]);
        }

        res.json({
            messages: result.rows.reverse(),
            next_cursor: result.rows.length === parseInt(limit) ? result.rows[result.rows.length - 1].id : null,
            has_more: result.rows.length === parseInt(limit)
        });
    } catch (err) {
        console.error("Erreur getMessages:", err);
        res.status(500).json({ error: "Erreur récupération messages" });
    }
};

/**
 * Rechercher des utilisateurs pour le chat
 */
exports.searchUsers = async (req, res) => {
    const { q } = req.query;
    const myId = req.user.id;
    if (!q || q.length < 2) return res.json([]);

    try {
        const result = await pool.query(`
            SELECT id, name, avatar_url, phone, id_oli FROM users 
            WHERE (name ILIKE $1 OR phone ILIKE $1 OR id_oli ILIKE $1) AND id != $2 LIMIT 20`,
            [`%${q}%`, myId]
        );
        res.json(result.rows);
    } catch (err) {
        console.error("Erreur searchUsers:", err);
        res.status(500).json({ error: "Erreur recherche" });
    }
};
