/**
 * Routes Chat Oli
 * Messagerie temps réel - Conversations, Messages, Médias
 */
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { BASE_URL } = require('../config');
const { chatUpload } = require('../config/upload');

// --- HELPER FUNCTIONS ---

/**
 * Vérifie si un utilisateur peut envoyer un message à un autre
 */
async function canSendMessage(senderId, recipientId) {
    const res = await pool.query(
        `SELECT * FROM friendships 
         WHERE (requester_id = $1 AND addressee_id = $2) 
            OR (requester_id = $2 AND addressee_id = $1)`,
        [senderId, recipientId]
    );

    if (res.rows.length === 0) {
        return { allowed: true, isNewRequest: true };
    }

    const friendship = res.rows[0];

    if (friendship.status === 'accepted') {
        return { allowed: true, isNewRequest: false };
    }

    if (friendship.status === 'pending') {
        // L'addressee peut toujours répondre
        if (friendship.addressee_id === senderId) {
            return { allowed: true, isNewRequest: false };
        }

        // Le requester a une limite de 3 messages en attente d'acceptation
        const msgCheck = await pool.query(`
            SELECT COUNT(*) FROM messages m 
            JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id 
            WHERE cp.user_id = $1 AND m.sender_id = $1 
            AND cp.conversation_id IN (
                SELECT conversation_id FROM conversation_participants WHERE user_id = $2
            )`,
            [senderId, recipientId]
        );

        if (parseInt(msgCheck.rows[0].count) >= 3) {
            return {
                allowed: false,
                error: "Limite de messages atteinte. Attendez que le destinataire réponde."
            };
        }

        return { allowed: true, isNewRequest: false };
    }

    if (friendship.status === 'blocked') {
        return { allowed: false, error: "Vous ne pouvez pas contacter cet utilisateur." };
    }

    return { allowed: false, error: "Vous n'êtes pas autorisé à envoyer de message." };
}

// --- ROUTES ---

/**
 * POST /chat/upload
 * Upload d'image/audio pour le chat
 */
router.post('/upload', chatUpload.single('file'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: "Pas de fichier" });
    }

    const fileUrl = `${BASE_URL}/uploads/${req.file.filename}`;
    const fileType = req.file.mimetype.startsWith('image/') ? 'image' :
        req.file.mimetype.startsWith('audio/') ? 'audio' : 'file';

    res.json({ url: fileUrl, type: fileType });
});

/**
 * POST /chat/request
 * Démarrer une nouvelle conversation (premier message)
 */
router.post('/request', async (req, res) => {
    const { recipientId, content, type, productId } = req.body;
    const senderId = req.user.id;

    if (!recipientId || !content) {
        return res.status(400).json({ error: "Destinataire et contenu requis" });
    }

    try {
        // Vérifier si une conversation existe déjà pour ce produit
        if (productId) {
            const existingConv = await pool.query(`
                SELECT c.id FROM conversations c
                JOIN conversation_participants cp1 ON c.id = cp1.conversation_id AND cp1.user_id = $1
                JOIN conversation_participants cp2 ON c.id = cp2.conversation_id AND cp2.user_id = $2
                WHERE c.product_id = $3
            `, [senderId, recipientId, productId]);

            if (existingConv.rows.length > 0) {
                return res.status(400).json({
                    error: "Une conversation existe déjà pour ce produit.",
                    conversationId: existingConv.rows[0].id
                });
            }
        }

        // Créer ou mettre à jour la relation d'amitié
        const relCheck = await pool.query(
            `SELECT * FROM friendships 
             WHERE (requester_id = $1 AND addressee_id = $2) 
                OR (requester_id = $2 AND addressee_id = $1)`,
            [senderId, recipientId]
        );

        if (relCheck.rows.length === 0) {
            await pool.query(
                "INSERT INTO friendships (requester_id, addressee_id, status) VALUES ($1, $2, 'pending')",
                [senderId, recipientId]
            );
        }

        // Créer la conversation
        const convRes = await pool.query(
            "INSERT INTO conversations (type, product_id) VALUES ('private', $1) RETURNING id",
            [productId || null]
        );
        const convId = convRes.rows[0].id;

        // Ajouter les participants
        await pool.query(
            "INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1, $2), ($1, $3)",
            [convId, senderId, recipientId]
        );

        // Insérer le message
        const msgRes = await pool.query(`
            INSERT INTO messages (conversation_id, sender_id, type, content) 
            VALUES ($1, $2, $3, $4) RETURNING *`,
            [convId, senderId, type || 'text', content]
        );

        const message = msgRes.rows[0];

        // Émettre via Socket.IO
        const io = req.app.get('io');
        if (io) {
            io.to(`user_${recipientId}`).emit('new_request', {
                from: { id: req.user.id, phone: req.user.phone },
                message,
                conversationId: convId
            });
        }

        res.json({
            success: true,
            message,
            conversationId: convId
        });

    } catch (err) {
        console.error("Erreur POST /chat/request:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

/**
 * POST /chat/accept
 * Accepter une demande de conversation
 */
router.post('/accept', async (req, res) => {
    const { requesterId } = req.body;
    const addresseeId = req.user.id;

    try {
        await pool.query(
            "UPDATE friendships SET status = 'accepted', updated_at = NOW() WHERE requester_id = $1 AND addressee_id = $2",
            [requesterId, addresseeId]
        );

        const io = req.app.get('io');
        if (io) {
            io.to(`user_${requesterId}`).emit('request_accepted', { by: addresseeId });
        }

        res.json({ success: true });
    } catch (err) {
        console.error("Erreur POST /chat/accept:", err);
        res.status(500).json({ error: "Erreur acceptation" });
    }
});

/**
 * POST /chat/messages
 * Envoyer un message dans une conversation existante
 */
router.post('/messages', async (req, res) => {
    const { conversationId, recipientId, content, type, amount, replyToId } = req.body;
    const senderId = req.user.id;

    if (!conversationId || !content) {
        return res.status(400).json({ error: "conversationId et content requis" });
    }

    try {
        // Vérifier permissions
        const check = await canSendMessage(senderId, recipientId);
        if (!check.allowed) {
            return res.status(403).json({ error: check.error });
        }

        // Auto-accepter si l'addressee répond
        const relRes = await pool.query(
            `SELECT * FROM friendships 
             WHERE (requester_id = $1 AND addressee_id = $2) 
                OR (requester_id = $2 AND addressee_id = $1)`,
            [senderId, recipientId]
        );

        if (relRes.rows.length > 0) {
            const rel = relRes.rows[0];
            if (rel.status === 'pending' && rel.addressee_id === senderId) {
                await pool.query(
                    "UPDATE friendships SET status = 'accepted', updated_at = NOW() WHERE id = $1",
                    [rel.id]
                );
                console.log(`✅ Relation ${rel.id} auto-acceptée`);
            }
        }

        // Insérer le message
        const msgRes = await pool.query(`
            INSERT INTO messages (conversation_id, sender_id, type, content, amount, reply_to_id) 
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [conversationId, senderId, type || 'text', content, amount || null, replyToId || null]
        );

        let fullMessage = msgRes.rows[0];

        // Récupérer le contenu du parent si c'est une réponse
        if (replyToId) {
            const parentRes = await pool.query("SELECT content, sender_id FROM messages WHERE id = $1", [replyToId]);
            if (parentRes.rows.length > 0) {
                fullMessage.reply_to_content = parentRes.rows[0].content;
                fullMessage.reply_to_sender = parentRes.rows[0].sender_id;
            }
        }

        // Mettre à jour la conversation
        await pool.query("UPDATE conversations SET updated_at = NOW() WHERE id = $1", [conversationId]);

        // Émettre via Socket.IO
        const io = req.app.get('io');
        if (io && recipientId) {
            io.to(`user_${recipientId}`).emit('new_message', fullMessage);
        }

        res.json(fullMessage);
    } catch (err) {
        console.error("Erreur POST /chat/messages:", err);
        res.status(500).json({ error: "Erreur envoi" });
    }
});

/**
 * POST /chat/messages/:id/read
 * Marquer un message comme lu
 */
router.post('/messages/:id/read', async (req, res) => {
    const { id } = req.params;

    try {
        await pool.query(
            "UPDATE messages SET is_read = true WHERE id = $1 AND sender_id != $2",
            [id, req.user.id]
        );

        // Émettre l'accusé de lecture
        const msg = await pool.query("SELECT * FROM messages WHERE id = $1", [id]);
        if (msg.rows.length > 0) {
            const io = req.app.get('io');
            if (io) {
                io.to(`user_${msg.rows[0].sender_id}`).emit('message_read', {
                    messageId: id,
                    conversationId: msg.rows[0].conversation_id,
                    readBy: req.user.id
                });
            }
        }

        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: "Erreur" });
    }
});

/**
 * GET /chat/conversations
 * Liste des conversations de l'utilisateur
 */
router.get('/conversations', async (req, res) => {
    const myId = req.user.id;

    try {
        const result = await pool.query(`
            SELECT 
                c.id as conversation_id, 
                u.name as other_name, 
                u.avatar_url as other_avatar, 
                u.id as other_id, 
                u.phone as other_phone,
                m.content as last_message, 
                m.type as last_message_type,
                m.created_at as last_time,
                m.sender_id as last_sender_id,
                p.id as product_id, 
                p.name as product_name, 
                p.price as product_price,
                p.images as product_images_raw,
                f.status as friendship_status, 
                f.requester_id,
                (SELECT COUNT(*) FROM messages msg WHERE msg.conversation_id = c.id AND msg.is_read = false AND msg.sender_id != $1) as unread_count
            FROM conversation_participants cp
            JOIN conversations c ON cp.conversation_id = c.id
            JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
            JOIN users u ON cp2.user_id = u.id
            LEFT JOIN friendships f ON (f.requester_id = cp.user_id AND f.addressee_id = cp2.user_id) 
                                    OR (f.requester_id = cp2.user_id AND f.addressee_id = cp.user_id)
            LEFT JOIN products p ON c.product_id = p.id
            LEFT JOIN LATERAL (
                SELECT content, type, created_at, sender_id 
                FROM messages WHERE conversation_id = c.id 
                ORDER BY created_at DESC LIMIT 1
            ) m ON true
            WHERE cp.user_id = $1
            ORDER BY m.created_at DESC NULLS LAST
        `, [myId]);

        // Post-traitement
        const conversations = result.rows.map(row => {
            let imgUrl = null;
            if (row.product_images_raw) {
                let imgs = Array.isArray(row.product_images_raw)
                    ? row.product_images_raw
                    : row.product_images_raw.replace(/[{}\"]/g, '').split(',');

                if (imgs.length > 0 && imgs[0]) {
                    imgUrl = imgs[0].startsWith('http') ? imgs[0] : `${BASE_URL}/uploads/${imgs[0]}`;
                }
            }

            return {
                ...row,
                product_image: imgUrl,
                product_images_raw: undefined,
                unread_count: parseInt(row.unread_count) || 0
            };
        });

        res.json(conversations);
    } catch (err) {
        console.error("Erreur GET /chat/conversations:", err);
        res.status(500).json({ error: "Erreur" });
    }
});

/**
 * GET /chat/messages/:otherUserId
 * Historique des messages avec un utilisateur
 */
router.get('/messages/:otherUserId', async (req, res) => {
    const myId = req.user.id;
    const { otherUserId } = req.params;
    const { productId, limit = 100 } = req.query;

    try {
        let conversationFilter = "";
        const params = [myId, otherUserId, parseInt(limit)];

        if (productId) {
            conversationFilter = `AND c.product_id = $4`;
            params.push(productId);
        }

        const result = await pool.query(`
            SELECT 
                m.*, 
                u.name as sender_name, 
                u.phone as sender_phone,
                u.avatar_url as sender_avatar,
                c.product_id, 
                c.id as conversation_id,
                parent.content as reply_to_content, 
                parent.sender_id as reply_to_sender,
                f.status as friendship_status, 
                f.requester_id
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            JOIN conversations c ON m.conversation_id = c.id
            LEFT JOIN messages parent ON m.reply_to_id = parent.id
            LEFT JOIN friendships f ON (f.requester_id = $1 AND f.addressee_id = $2) 
                                    OR (f.requester_id = $2 AND f.addressee_id = $1)
            WHERE m.conversation_id IN (
                SELECT cp1.conversation_id 
                FROM conversation_participants cp1
                JOIN conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
                JOIN conversations c ON cp1.conversation_id = c.id
                WHERE cp1.user_id = $1 AND cp2.user_id = $2
                ${conversationFilter}
            )
            ORDER BY m.created_at ASC
            LIMIT $3
        `, params);

        // Marquer comme lu
        if (result.rows.length > 0) {
            const convId = result.rows[0].conversation_id;
            await pool.query(
                "UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id = $2 AND is_read = false",
                [convId, otherUserId]
            );
        }

        res.json(result.rows);
    } catch (err) {
        console.error("Erreur GET /chat/messages/:otherUserId:", err);
        res.status(500).json({ error: "Erreur récupération messages" });
    }
});

/**
 * GET /chat/users
 * Rechercher des utilisateurs pour démarrer une conversation
 */
router.get('/users', async (req, res) => {
    const { q } = req.query;
    const myId = req.user.id;

    if (!q || q.length < 2) {
        return res.json([]);
    }

    try {
        const result = await pool.query(`
            SELECT id, name, avatar_url, phone, id_oli 
            FROM users 
            WHERE (name ILIKE $1 OR phone ILIKE $1 OR id_oli ILIKE $1) 
              AND id != $2 
            LIMIT 20`,
            [`%${q}%`, myId]
        );
        res.json(result.rows);
    } catch (err) {
        console.error("Erreur GET /chat/users:", err);
        res.status(500).json({ error: "Erreur recherche" });
    }
});

module.exports = router;
