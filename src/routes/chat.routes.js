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
 * Démarrer une nouvelle conversation
 */
rrouter.post('/send', async (req, res) => {
    const { recipientId, content, type = 'text', productId, metadata, conversationId: existingConvId } = req.body;
    const senderId = req.user.id;

    try {
        // 1. Gérer la conversation
        let conversationId = existingConvId;

        if (!conversationId) {
            // Vérifier si une discussion existe déjà pour ce produit entre ces deux-là
            const convCheck = await pool.query(
                `SELECT id FROM conversations 
                 WHERE product_id = $1 AND ((user1_id = $2 AND user2_id = $3) OR (user1_id = $3 AND user2_id = $2))`,
                [productId, senderId, recipientId]
            );

            if (convCheck.rows.length > 0) {
                conversationId = convCheck.rows[0].id;
            } else {
                // Créer la conversation
                const newConv = await pool.query(
                    "INSERT INTO conversations (user1_id, user2_id, product_id) VALUES ($1, $2, $3) RETURNING id",
                    [senderId, recipientId, productId]
                );
                conversationId = newConv.rows[0].id;

                // Créer la relation d'amitié (auto-acceptée pour le commerce)
                await pool.query(
                    `INSERT INTO friendships (requester_id, addressee_id, status) 
                     VALUES ($1, $2, 'accepted') 
                     ON CONFLICT (requester_id, addressee_id) DO NOTHING`,
                    [senderId, recipientId]
                );
            }
        }

        // 2. Insérer le message
        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, metadata) 
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [conversationId, senderId, content, type, metadata ? JSON.stringify(metadata) : null]
        );

        const newMessage = msgResult.rows[0];

        // 3. ENVOI TEMPS RÉEL (SOCKET.IO)
        const io = req.app.get('io');

        // On envoie au destinataire dans sa room personnelle
        // C'est ça qui fait apparaître la discussion chez le vendeur !
        io.to(`user_${recipientId}`).emit('new_message', {
            ...newMessage,
            conversation_id: conversationId // Crucial pour le rafraîchissement
        });

        // On envoie aussi un signal "nouvelle requête" pour forcer la mise à jour de la liste
        io.to(`user_${recipientId}`).emit('new_request', {
            sender_id: senderId,
            conversation_id: conversationId
        });

        res.json({ success: true, message: newMessage, conversationId });

    } catch (err) {
        console.error("Erreur envoi message:", err);
        res.status(500).json({ error: "Erreur lors de l'envoi" });
    }
});

/**
 * POST /chat/messages
 * Envoyer un message dans une conversation existante
 */
router.post('/messages', async (req, res) => {
    const { conversationId, content, type, amount, replyToId, metadata } = req.body;
    let { recipientId } = req.body;
    const senderId = req.user.id;

    if (!conversationId || !content) {
        return res.status(400).json({ error: "conversationId et content requis" });
    }

    try {
        // 1. Trouver le destinataire si manquant
        if (!recipientId) {
            const partRes = await pool.query(
                "SELECT user_id FROM conversation_participants WHERE conversation_id = $1 AND user_id != $2",
                [conversationId, senderId]
            );
            if (partRes.rows.length > 0) recipientId = partRes.rows[0].user_id;
        }

        // 2. Vérifier les permissions
        const check = await canSendMessage(senderId, recipientId);
        if (!check.allowed) return res.status(403).json({ error: check.error });

        // 3. Auto-accepter la relation si l'autre répond
        const relRes = await pool.query(
            "SELECT id, status, addressee_id FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
            [senderId, recipientId]
        );
        if (relRes.rows.length > 0) {
            const rel = relRes.rows[0];
            if (rel.status === 'pending' && rel.addressee_id === senderId) {
                await pool.query("UPDATE friendships SET status = 'accepted', updated_at = NOW() WHERE id = $1", [rel.id]);
                console.log(`✅ Relation ${rel.id} auto-acceptée`);
            }
        }

        // 4. Insérer le message
        const msgRes = await pool.query(`
            INSERT INTO messages (conversation_id, sender_id, type, content, amount, reply_to_id, metadata) 
            VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
            [conversationId, senderId, type || 'text', content, amount || null, replyToId || null, metadata || null]
        );

        let fullMessage = msgRes.rows[0];

        // 5. Gérer les détails de la réponse (Reply)
        if (replyToId) {
            const parentRes = await pool.query("SELECT content, sender_id FROM messages WHERE id = $1", [replyToId]);
            if (parentRes.rows.length > 0) {
                fullMessage.reply_to_content = parentRes.rows[0].content;
                fullMessage.reply_to_sender = parentRes.rows[0].sender_id;
            }
        }

        // 6. Mettre à jour le timestamp de la conversation
        await pool.query("UPDATE conversations SET updated_at = NOW() WHERE id = $1", [conversationId]);

        // 7. Envoi Socket
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
 * GET /chat/conversations
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

// ... (Les autres routes GET /messages/:otherUserId et GET /users restent identiques)

module.exports = router;