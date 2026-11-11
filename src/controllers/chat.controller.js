const pool = require('../config/db');
const { BASE_URL } = require('../config');
const presence = require('../services/presence.service');
const { attestCashTransfer } = require('../services/cash-message.service');

const MAX_PINNED_CONVERSATIONS = 3;
const CONVERSATION_FLAGS = ['is_archived', 'is_favorite', 'is_pinned', 'marked_unread'];

// Expressions SQL fixes : la durée reçue sert uniquement de clé
const MUTE_UNTIL_SQL = new Map([
    ['8h', "NOW() + INTERVAL '8 hours'"],
    ['1w', "NOW() + INTERVAL '7 days'"],
    ['always', "'9999-12-31'::timestamptz"],
    ['off', 'NULL'],
]);

async function getBlockBetween(senderId, recipientId) {
    const { rows } = await pool.query(
        `SELECT blocker_id FROM user_blocks
         WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)`,
        [senderId, recipientId]
    );
    return {
        senderBlockedRecipient: rows.some((r) => String(r.blocker_id) === String(senderId)),
        recipientBlockedSender: rows.some((r) => String(r.blocker_id) === String(recipientId)),
    };
}

const YOU_BLOCKED_RESPONSE = { error: 'Débloquez ce contact pour lui écrire', code: 'you_blocked' };
const BLOCKED_BY_RECIPIENT_RESPONSE = {
    error: "Ce contact vous a bloqué. Votre message ne peut pas lui être distribué.",
    code: 'blocked_by_recipient',
};
const HIDDEN_BEFORE = `COALESCE(cp.hidden_at, '-infinity'::timestamptz)`;

// Délais laissés à l'auteur, comme sur les messageries courantes
const EDIT_WINDOW_MINUTES = 15;
const DELETE_FOR_ALL_WINDOW_HOURS = 48;
const MAX_FORWARD_RECIPIENTS = 5;
const MAX_MESSAGE_LENGTH = 4000;
const DELETED_PLACEHOLDER = '🚫 Message supprimé';
const MESSAGE_ID_PATTERN = /^\d+$/;

// Durées proposées pour les messages éphémères, en secondes
const EPHEMERAL_SECONDS = new Map([
    ['off', null],
    ['24h', 24 * 60 * 60],
    ['7d', 7 * 24 * 60 * 60],
    ['90d', 90 * 24 * 60 * 60],
]);
const NOT_EXPIRED = (alias) => `(${alias}.expires_at IS NULL OR ${alias}.expires_at > NOW())`;

/** Message visible par cet utilisateur, avec la preuve qu'il participe à la conversation. */
async function findMessageForParticipant(messageId, userId) {
    const { rows } = await pool.query(
        `SELECT m.* FROM messages m
         JOIN conversation_participants cp ON cp.conversation_id = m.conversation_id AND cp.user_id = $2
         WHERE m.id = $1`,
        [messageId, userId]
    );
    return rows[0] || null;
}

async function emitToConversation(req, conversationId, event, payload) {
    const io = req.app.get('io');
    if (!io) return;
    const { rows } = await pool.query(
        'SELECT user_id FROM conversation_participants WHERE conversation_id = $1',
        [conversationId]
    );
    rows.forEach((p) => io.to(`user_${p.user_id}`).emit(event, payload));
}

const isCashMessage = (message) => Boolean(message.metadata && message.metadata.cash_transfer);

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
    const { recipientId, content, type = 'text', productId, metadata, conversationId: existingConvId, latitude, longitude } = req.body;
    const senderId = req.user.id;

    try {
        const block = await getBlockBetween(senderId, recipientId);
        if (block.senderBlockedRecipient) return res.status(403).json(YOU_BLOCKED_RESPONSE);
        if (block.recipientBlockedSender) return res.status(403).json(BLOCKED_BY_RECIPIENT_RESPONSE);

        if (existingConvId) {
            const members = await pool.query(
                'SELECT COUNT(*)::int AS total FROM conversation_participants WHERE conversation_id = $1 AND user_id = ANY($2::int[])',
                [existingConvId, [senderId, recipientId]]
            );
            if (members.rows[0].total !== 2) return res.status(403).json({ error: 'Conversation non autorisée' });
        }

        let conversationId = existingConvId;
        let friendshipStatus = 'pending';
        let requesterId = senderId;

        if (!conversationId) {
            const convCheck = await pool.query(`
                SELECT c.id FROM conversations c
                JOIN conversation_participants cp1 ON cp1.conversation_id = c.id AND cp1.user_id = $1
                JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id = $2
                WHERE c.type = 'private' AND c.product_id IS NOT DISTINCT FROM $3 LIMIT 1
            `, [senderId, recipientId, productId || null]);

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

        // Enrichir metadata avec les coordonnées GPS si c'est un message location
        let msgMetadata = await attestCashTransfer(metadata, { conversationId, senderId, recipientId });
        if (type === 'location' && latitude && longitude) {
            msgMetadata = { ...msgMetadata, latitude, longitude };
        }
        const msgContent = content || (type === 'location' ? '📍 Position partagée' : content);

        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, metadata, latitude, longitude, delivered_at) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
            [conversationId, senderId, msgContent, type, JSON.stringify(msgMetadata), latitude || null, longitude || null, presence.isOnline(recipientId) ? new Date() : null]
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
    const { conversationId, type, amount, replyToId, mediaUrl, mediaType, latitude, longitude } = req.body;
    let { content, recipientId, metadata } = req.body;
    const senderId = req.user.id;

    // Validation : Soit du contenu, soit un média, soit une location/metadata est requis
    if (!conversationId || (!content && !mediaUrl && type !== 'location' && !metadata)) {
        return res.status(400).json({ error: "conversationId et content (ou mediaUrl/location) requis" });
    }

    // Si c'est un message média sans texte, on met un texte par défaut
    if (!content && type === 'location' && latitude && longitude) {
        content = '📍 Position partagée';
    } else if (!content && mediaUrl) {
        content = mediaType === 'image' ? '📷 Image' : '📎 Fichier';
    }

    // Enrichissement des métadonnées avec les infos média
    let messageMetadata = metadata || {};
    if (typeof messageMetadata === 'string') {
        try { messageMetadata = JSON.parse(messageMetadata); } catch (e) { }
    }

    // Coordonnées GPS pour les messages location
    if (type === 'location' && latitude && longitude) {
        messageMetadata.latitude = parseFloat(latitude);
        messageMetadata.longitude = parseFloat(longitude);
    }

    if (mediaUrl) {
        messageMetadata.mediaUrl = mediaUrl;
        messageMetadata.mediaType = mediaType || 'file';
    }

    try {
        // Le destinataire vient de la conversation : un identifiant envoyé par le client contournerait le blocage
        const participants = await pool.query(
            'SELECT user_id FROM conversation_participants WHERE conversation_id = $1',
            [conversationId]
        );
        if (!participants.rows.some((r) => String(r.user_id) === String(senderId))) {
            return res.status(403).json({ error: 'Conversation non autorisée' });
        }
        const other = participants.rows.find((r) => String(r.user_id) !== String(senderId));
        recipientId = other ? other.user_id : null;

        const block = await getBlockBetween(senderId, recipientId);
        if (block.senderBlockedRecipient) return res.status(403).json(YOU_BLOCKED_RESPONSE);
        if (block.recipientBlockedSender) return res.status(403).json(BLOCKED_BY_RECIPIENT_RESPONSE);

        messageMetadata = await attestCashTransfer(messageMetadata, { conversationId, senderId, recipientId });

        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, amount, reply_to_id, metadata, latitude, longitude, delivered_at) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
            [
                conversationId,
                senderId,
                content,
                type || (mediaUrl ? 'media' : 'text'),
                amount,
                replyToId,
                JSON.stringify(messageMetadata),
                (type === 'location' && latitude) ? parseFloat(latitude) : null,
                (type === 'location' && longitude) ? parseFloat(longitude) : null,
                presence.isOnline(recipientId) ? new Date() : null
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
            SELECT c.id as conversation_id, c.is_market, c.ephemeral_seconds, cp.is_archived, cp.is_favorite, cp.is_pinned, cp.marked_unread,
                (cp.muted_until IS NOT NULL AND cp.muted_until > NOW()) as is_muted,
                EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id = $1 AND b.blocked_id = u.id) as is_blocked,
                u.name as other_name, u.avatar_url as other_avatar, u.id as other_id, u.phone as other_phone,
                m.content as last_message, m.type as last_message_type, m.created_at as last_time, m.sender_id as last_sender_id,
                p.id as product_id, p.name as product_name, p.price as product_price, p.images as product_images_raw,
                f.status as friendship_status, f.requester_id,
                (SELECT COUNT(*) FROM messages msg WHERE msg.conversation_id = c.id AND msg.is_read = false AND msg.sender_id != $1 AND msg.created_at > ${HIDDEN_BEFORE}) as unread_count
            FROM conversation_participants cp
            JOIN conversations c ON cp.conversation_id = c.id
            JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
            JOIN users u ON cp2.user_id = u.id
            LEFT JOIN friendships f ON (f.requester_id = cp.user_id AND f.addressee_id = cp2.user_id) 
                                    OR (f.requester_id = cp2.user_id AND f.addressee_id = cp.user_id)
            LEFT JOIN products p ON c.product_id = p.id
            LEFT JOIN LATERAL (
                SELECT content, type, created_at, sender_id FROM messages lm
                WHERE lm.conversation_id = c.id AND ${NOT_EXPIRED('lm')}
                  AND NOT EXISTS (SELECT 1 FROM message_hidden_for h WHERE h.message_id = lm.id AND h.user_id = $1)
                ORDER BY lm.created_at DESC LIMIT 1
            ) m ON true
            WHERE cp.user_id = $1 AND (cp.hidden_at IS NULL OR m.created_at > cp.hidden_at)
            ORDER BY cp.is_pinned DESC, m.created_at DESC NULLS LAST
        `, [myId]);

        const conversations = result.rows.map(row => ({
            ...row,
            product_image: formatProductImage(row),
            product_images_raw: undefined,
            unread_count: Math.max(parseInt(row.unread_count) || 0, row.marked_unread ? 1 : 0),
            last_message_time: row.last_time,
            is_online: presence.isOnline(row.other_id)
        }));
        res.json(conversations);
    } catch (err) {
        console.error("Erreur getConversations:", err);
        res.status(500).json({ error: "Erreur" });
    }
};

/**
 * Modifier l'état personnel d'une conversation (archivée, favorite, épinglée)
 */
exports.updateConversationState = async (req, res) => {
    const myId = req.user.id;
    const { id } = req.params;
    const changes = CONVERSATION_FLAGS.filter((flag) => typeof req.body?.[flag] === 'boolean');

    if (!/^\d+$/.test(id) || changes.length === 0) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        if (req.body.is_pinned === true) {
            const pinned = await pool.query(
                `SELECT COUNT(*)::int AS total FROM conversation_participants
                 WHERE user_id = $1 AND is_pinned = TRUE AND conversation_id <> $2`,
                [myId, id]
            );
            if (pinned.rows[0].total >= MAX_PINNED_CONVERSATIONS) {
                return res.status(409).json({ error: 'Vous pouvez épingler 3 conversations au maximum' });
            }
        }

        const assignments = changes.map((flag, index) => `${flag} = $${index + 3}`).join(', ');
        const result = await pool.query(
            `UPDATE conversation_participants SET ${assignments}
             WHERE conversation_id = $1 AND user_id = $2
             RETURNING conversation_id, is_archived, is_favorite, is_pinned, marked_unread`,
            [id, myId, ...changes.map((flag) => req.body[flag])]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation introuvable' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erreur updateConversationState:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Marquer un vocal comme écouté : seul le destinataire peut le faire, une seule fois.
 */
exports.markVoicePlayed = async (req, res) => {
    const { messageId } = req.params;
    if (!/^\d+$/.test(messageId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const { rows } = await pool.query(
            `UPDATE messages m SET played_at = NOW()
             WHERE m.id = $1
               AND m.sender_id <> $2
               AND m.played_at IS NULL
               AND (m.type = 'audio' OR m.metadata->>'mediaType' = 'audio')
               AND EXISTS (
                   SELECT 1 FROM conversation_participants cp
                   WHERE cp.conversation_id = m.conversation_id AND cp.user_id = $2
               )
             RETURNING m.id, m.sender_id, m.conversation_id, m.played_at`,
            [messageId, req.user.id]
        );

        const played = rows[0];
        if (played) {
            const io = req.app.get('io');
            if (io) {
                io.to(`user_${played.sender_id}`).emit('message_played', {
                    message_id: played.id,
                    conversation_id: played.conversation_id,
                    played_at: played.played_at,
                });
            }
        }
        res.json({ played: Boolean(played) });
    } catch (err) {
        console.error('Erreur markVoicePlayed:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Messages éphémères : la durée vaut pour les deux participants et pour les messages envoyés ensuite.
 */
exports.setConversationEphemeral = async (req, res) => {
    const { id } = req.params;
    const { duration } = req.body || {};
    if (!MESSAGE_ID_PATTERN.test(id) || !EPHEMERAL_SECONDS.has(duration)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const seconds = EPHEMERAL_SECONDS.get(duration);
        const { rows } = await pool.query(
            `UPDATE conversations c SET ephemeral_seconds = $1
             WHERE c.id = $2
               AND EXISTS (SELECT 1 FROM conversation_participants cp WHERE cp.conversation_id = c.id AND cp.user_id = $3)
             RETURNING c.id, c.ephemeral_seconds`,
            [seconds, id, req.user.id]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'Conversation introuvable' });

        await emitToConversation(req, rows[0].id, 'conversation_ephemeral', {
            conversation_id: rows[0].id,
            ephemeral_seconds: rows[0].ephemeral_seconds,
            changed_by: req.user.id,
        });
        res.json({ success: true, ephemeral_seconds: rows[0].ephemeral_seconds });
    } catch (err) {
        console.error('Erreur setConversationEphemeral:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Couper ou réactiver les notifications d'une conversation
 */
exports.setConversationMute = async (req, res) => {
    const { id } = req.params;
    const untilSql = MUTE_UNTIL_SQL.get(req.body?.duration);
    if (!/^\d+$/.test(id) || !untilSql) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const result = await pool.query(
            `UPDATE conversation_participants SET muted_until = ${untilSql}
             WHERE conversation_id = $1 AND user_id = $2
             RETURNING (muted_until IS NOT NULL AND muted_until > NOW()) AS is_muted`,
            [id, req.user.id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation introuvable' });
        }
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Erreur setConversationMute:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

exports.blockUser = async (req, res) => {
    const { userId } = req.params;
    if (!/^\d+$/.test(userId) || userId === String(req.user.id)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        await pool.query(
            'INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [req.user.id, userId]
        );
        res.json({ is_blocked: true });
    } catch (err) {
        console.error('Erreur blockUser:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

exports.unblockUser = async (req, res) => {
    const { userId } = req.params;
    if (!/^\d+$/.test(userId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        await pool.query('DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2', [req.user.id, userId]);
        res.json({ is_blocked: false });
    } catch (err) {
        console.error('Erreur unblockUser:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Marquer comme lus les messages reçus dans une conversation
 */
exports.markConversationRead = async (req, res) => {
    const myId = req.user.id;
    const { id } = req.params;
    if (!/^\d+$/.test(id)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const member = await pool.query(
            'SELECT 1 FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2',
            [id, myId]
        );
        if (member.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation introuvable' });
        }

        await pool.query(
            'UPDATE conversation_participants SET marked_unread = FALSE WHERE conversation_id = $1 AND user_id = $2',
            [id, myId]
        );

        const result = await pool.query(
            `UPDATE messages SET is_read = TRUE
             WHERE conversation_id = $1 AND sender_id <> $2 AND is_read = FALSE
             RETURNING sender_id`,
            [id, myId]
        );

        const io = req.app.get('io');
        if (io && result.rowCount > 0) {
            io.to(`user_${result.rows[0].sender_id}`).emit('messages_read', {
                conversation_id: Number(id),
                reader_id: myId,
                read_count: result.rowCount,
            });
        }
        res.json({ read_count: result.rowCount });
    } catch (err) {
        console.error('Erreur markConversationRead:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Retirer une conversation pour moi seul : l'autre participant garde son historique.
 * Elle réapparaît, sans les anciens messages, si un nouveau message arrive.
 */
exports.deleteConversationForMe = async (req, res) => {
    const myId = req.user.id;
    const { id } = req.params;
    if (!/^\d+$/.test(id)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const result = await pool.query(
            `UPDATE conversation_participants
             SET hidden_at = NOW(), is_archived = FALSE, is_favorite = FALSE, is_pinned = FALSE
             WHERE conversation_id = $1 AND user_id = $2
             RETURNING conversation_id`,
            [id, myId]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation introuvable' });
        }
        res.json({ success: true });
    } catch (err) {
        console.error('Erreur deleteConversationForMe:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Savoir si un interlocuteur est connecté
 */
exports.getPresence = async (req, res) => {
    const myId = req.user.id;
    const { userId } = req.params;
    if (!/^\d+$/.test(userId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const shared = await pool.query(
            `SELECT 1 FROM conversation_participants mine
             JOIN conversation_participants other ON other.conversation_id = mine.conversation_id
             WHERE mine.user_id = $1 AND other.user_id = $2
             LIMIT 1`,
            [myId, userId]
        );
        res.json({ online: shared.rows.length > 0 && presence.isOnline(userId) });
    } catch (err) {
        console.error('Erreur getPresence:', err);
        res.status(500).json({ error: 'Erreur' });
    }
};

/**
 * Récupérer les messages d'une conversation
 */
exports.getMessages = async (req, res) => {
    const myId = req.user.id;
    const { otherUserId } = req.params;
    const { productId, scope, limit = 50, cursor } = req.query;

    try {
        let conversationFilter = "";
        const params = [myId, otherUserId];
        let paramIndex = 3;

        let cursorCondition = "";
        if (cursor) {
            cursorCondition = `AND m.id < $${paramIndex}`;
            params.push(parseInt(cursor));
            paramIndex++;
        }

        // Chaque produit a sa conversation : la discussion privée reste séparée
        if (productId && /^\d+$/.test(String(productId))) {
            conversationFilter = `AND cp1.conversation_id IN (SELECT id FROM conversations WHERE product_id = $${paramIndex})`;
            params.push(parseInt(productId));
            paramIndex++;
        } else if (scope === 'private') {
            conversationFilter = `AND cp1.conversation_id IN (SELECT id FROM conversations WHERE product_id IS NULL)`;
        }

        params.push(parseInt(limit));

        const result = await pool.query(`
            SELECT m.*, u.name as sender_name, u.phone as sender_phone, u.avatar_url as sender_avatar,
                c.product_id, c.id as conversation_id, c.ephemeral_seconds, parent.content as reply_to_content, parent.sender_id as reply_to_sender,
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
            AND m.created_at > COALESCE((
                SELECT mine.hidden_at FROM conversation_participants mine
                WHERE mine.conversation_id = m.conversation_id AND mine.user_id = $1
            ), '-infinity'::timestamptz)
            AND NOT EXISTS (SELECT 1 FROM message_hidden_for h WHERE h.message_id = m.id AND h.user_id = $1)
            AND ${NOT_EXPIRED('m')}
            ${cursorCondition} ORDER BY m.created_at DESC LIMIT $${paramIndex}
        `, params);

        if (result.rows.length > 0) {
            const convId = result.rows[0].conversation_id;
            await pool.query(
                'UPDATE conversation_participants SET marked_unread = FALSE WHERE conversation_id = $1 AND user_id = $2 AND marked_unread',
                [convId, myId]
            );
            const updateResult = await pool.query("UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id = $2 AND is_read = false RETURNING id", [convId, otherUserId]);

            // 🔥 NOUVEAU : Notifier l'expéditeur que ses messages ont été lus
            if (updateResult.rowCount > 0) {
                const io = req.app.get('io');
                if (io) {
                    io.to(`user_${otherUserId}`).emit('messages_read', {
                        conversation_id: convId,
                        reader_id: myId,
                        read_count: updateResult.rowCount
                    });
                }
            }
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
 * Ajouter / Retirer une réaction emoji sur un message
 */
exports.reactToMessage = async (req, res) => {
    const { messageId } = req.params;
    const { emoji } = req.body;
    const userId = req.user.id;

    if (!emoji) return res.status(400).json({ error: 'emoji requis' });

    try {
        // Récupérer les réactions actuelles
        const msgResult = await pool.query(
            'SELECT reactions, conversation_id FROM messages WHERE id = $1',
            [messageId]
        );
        if (msgResult.rows.length === 0) return res.status(404).json({ error: 'Message introuvable' });

        const msg = msgResult.rows[0];
        const reactions = msg.reactions || {};

        // Toggle
        const current = reactions[emoji] || 0;
        if (current > 0) {
            reactions[emoji] = current - 1;
            if (reactions[emoji] === 0) delete reactions[emoji];
        } else {
            reactions[emoji] = current + 1;
        }

        // Sauvegarder
        await pool.query(
            'UPDATE messages SET reactions = $1 WHERE id = $2',
            [JSON.stringify(reactions), messageId]
        );

        // Notifier via Socket.IO
        const io = req.app.get('io');
        if (io) {
            const participants = await pool.query(
                'SELECT user_id FROM conversation_participants WHERE conversation_id = $1',
                [msg.conversation_id]
            );
            participants.rows.forEach(p => {
                io.to(`user_${p.user_id}`).emit('reaction_updated', {
                    message_id: parseInt(messageId),
                    reactions,
                    conversation_id: msg.conversation_id,
                });
            });
        }

        res.json({ success: true, reactions });
    } catch (err) {
        console.error('Erreur reactToMessage:', err);
        res.status(500).json({ error: 'Erreur réaction' });
    }
};

/**
 * Modifier le texte d'un message : seul l'auteur, sur un message texte, dans les 15 minutes.
 */
exports.editMessage = async (req, res) => {
    const { messageId } = req.params;
    const content = typeof req.body.content === 'string' ? req.body.content.trim() : '';
    if (!MESSAGE_ID_PATTERN.test(messageId) || !content || content.length > MAX_MESSAGE_LENGTH) {
        return res.status(400).json({ error: 'Texte du message invalide' });
    }

    try {
        const { rows } = await pool.query(
            `UPDATE messages SET content = $1, edited_at = NOW()
             WHERE id = $2 AND sender_id = $3
               AND deleted_at IS NULL
               AND COALESCE(type, 'text') = 'text'
               AND created_at > NOW() - make_interval(mins => $4)
             RETURNING id, conversation_id, content, edited_at`,
            [content, messageId, req.user.id, EDIT_WINDOW_MINUTES]
        );
        const edited = rows[0];
        if (!edited) {
            return res.status(403).json({ error: `Un message ne peut être modifié que par son auteur, dans les ${EDIT_WINDOW_MINUTES} minutes` });
        }

        await emitToConversation(req, edited.conversation_id, 'message_edited', {
            message_id: edited.id,
            conversation_id: edited.conversation_id,
            content: edited.content,
            edited_at: edited.edited_at,
        });
        res.json({ success: true, message: edited });
    } catch (err) {
        console.error('Erreur editMessage:', err);
        res.status(500).json({ error: 'Erreur lors de la modification' });
    }
};

/**
 * Supprimer un message.
 * - pour moi (?for=me) : il disparaît seulement de ma discussion ;
 * - pour tous (?for=all) : l'auteur efface le contenu chez les deux participants, dans les 48 heures.
 * Un billet de cash reste : c'est la trace d'un transfert d'argent.
 */
exports.deleteMessage = async (req, res) => {
    const { messageId } = req.params;
    const forAll = req.query.for === 'all';
    if (!MESSAGE_ID_PATTERN.test(messageId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const message = await findMessageForParticipant(messageId, req.user.id);
        if (!message) return res.status(404).json({ error: 'Message introuvable' });

        if (!forAll) {
            await pool.query(
                `INSERT INTO message_hidden_for (message_id, user_id) VALUES ($1, $2)
                 ON CONFLICT DO NOTHING`,
                [messageId, req.user.id]
            );
            return res.json({ success: true });
        }

        if (String(message.sender_id) !== String(req.user.id)) {
            return res.status(403).json({ error: 'Seul l\'auteur peut supprimer ce message pour tous' });
        }
        if (isCashMessage(message)) {
            return res.status(403).json({ error: 'Un transfert d\'argent ne peut pas être supprimé pour tous' });
        }

        const { rows } = await pool.query(
            `UPDATE messages
             SET content = $1, metadata = '{"deleted": true}'::jsonb, reactions = NULL,
                 latitude = NULL, longitude = NULL, deleted_at = NOW()
             WHERE id = $2 AND deleted_at IS NULL
               AND created_at > NOW() - make_interval(hours => $3)
             RETURNING id, conversation_id, content, deleted_at`,
            [DELETED_PLACEHOLDER, messageId, DELETE_FOR_ALL_WINDOW_HOURS]
        );
        const deleted = rows[0];
        if (!deleted) {
            return res.status(403).json({ error: `Un message ne peut être supprimé pour tous que dans les ${DELETE_FOR_ALL_WINDOW_HOURS} heures` });
        }

        await emitToConversation(req, deleted.conversation_id, 'message_deleted', {
            message_id: deleted.id,
            conversation_id: deleted.conversation_id,
            content: deleted.content,
            deleted_at: deleted.deleted_at,
        });
        res.json({ success: true, message: deleted });
    } catch (err) {
        console.error('Erreur deleteMessage:', err);
        res.status(500).json({ error: 'Erreur lors de la suppression' });
    }
};

/**
 * Transférer un message vers d'autres discussions (5 au plus).
 * Le serveur recopie le message d'origine : le client ne peut rien y ajouter.
 */
exports.forwardMessage = async (req, res) => {
    const { messageId } = req.params;
    const senderId = req.user.id;
    const conversationIds = Array.isArray(req.body.conversationIds)
        ? [...new Set(req.body.conversationIds.map(String))].filter((id) => MESSAGE_ID_PATTERN.test(id))
        : [];
    if (!MESSAGE_ID_PATTERN.test(messageId) || conversationIds.length === 0) {
        return res.status(400).json({ error: 'Choisissez au moins une discussion' });
    }
    if (conversationIds.length > MAX_FORWARD_RECIPIENTS) {
        return res.status(400).json({ error: `${MAX_FORWARD_RECIPIENTS} discussions au maximum` });
    }

    try {
        const original = await findMessageForParticipant(messageId, senderId);
        if (!original || original.deleted_at) return res.status(404).json({ error: 'Message introuvable' });
        if (isCashMessage(original)) {
            return res.status(403).json({ error: 'Un transfert d\'argent ne peut pas être transféré' });
        }

        // Seuls le média et la forme du message voyagent : pas de produit, de réponse ni de réaction
        const source = original.metadata || {};
        const metadata = { forwarded: true };
        for (const key of ['mediaUrl', 'mediaType', 'duration_ms', 'waveform', 'lat', 'lng', 'latitude', 'longitude']) {
            if (source[key] !== undefined) metadata[key] = source[key];
        }

        const { rows: targets } = await pool.query(
            `SELECT mine.conversation_id, other.user_id AS recipient_id
             FROM conversation_participants mine
             JOIN conversation_participants other
               ON other.conversation_id = mine.conversation_id AND other.user_id <> mine.user_id
             WHERE mine.user_id = $1 AND mine.conversation_id = ANY($2::int[])`,
            [senderId, conversationIds]
        );

        const io = req.app.get('io');
        const sent = [];
        const skipped = [];
        for (const target of targets) {
            const block = await getBlockBetween(senderId, target.recipient_id);
            if (block.senderBlockedRecipient || block.recipientBlockedSender) {
                skipped.push(target.conversation_id);
                continue;
            }

            const { rows } = await pool.query(
                `INSERT INTO messages (conversation_id, sender_id, content, type, metadata, latitude, longitude, delivered_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
                [
                    target.conversation_id,
                    senderId,
                    original.content,
                    original.type || 'text',
                    JSON.stringify(metadata),
                    original.latitude,
                    original.longitude,
                    presence.isOnline(target.recipient_id) ? new Date() : null,
                ]
            );
            const message = rows[0];
            sent.push(message.id);
            if (io) {
                io.to(`user_${target.recipient_id}`).emit('new_message', message);
                io.to(`user_${senderId}`).emit('new_message', message);
            }
        }

        if (sent.length === 0) {
            return res.status(403).json({ error: 'Aucune des discussions choisies ne peut recevoir ce message' });
        }
        res.json({ success: true, sent: sent.length, skipped: skipped.length });
    } catch (err) {
        console.error('Erreur forwardMessage:', err);
        res.status(500).json({ error: 'Erreur lors du transfert' });
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
