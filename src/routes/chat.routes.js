/**
 * Routes Chat Oli - CORRIGÉ
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
 * POST /chat/send
 * Démarrer une nouvelle conversation (Premier message)
 */
router.post('/send', async (req, res) => {
    const { recipientId, content, type = 'text', productId, metadata, conversationId: existingConvId } = req.body;
    const senderId = req.user.id;

    console.log('\n📨 [/SEND] Nouveau message:');
    console.log(`   Sender: ${senderId}`);
    console.log(`   Recipient: ${recipientId}`);
    console.log(`   Content: ${content.substring(0, 50)}...`);
    console.log(`   Product: ${productId}`);

    try {
        // 1. Gérer la conversation
        let conversationId = existingConvId;
        let friendshipStatus = 'pending';
        let requesterId = senderId;

        if (!conversationId) {
            // Vérifier si une discussion existe déjà pour ce produit
            const convCheck = await pool.query(`
                SELECT c.id 
                FROM conversations c
                JOIN conversation_participants cp1 ON cp1.conversation_id = c.id AND cp1.user_id = $1
                JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id = $2
                WHERE c.product_id = $3 
                  AND c.type = 'private'
                LIMIT 1
            `, [senderId, recipientId, productId]);

            if (convCheck.rows.length > 0) {
                conversationId = convCheck.rows[0].id;
                // Récupérer le statut existant
                const fCheck = await pool.query(`SELECT status, requester_id FROM friendships WHERE (requester_id=$1 AND addressee_id=$2) OR (requester_id=$2 AND addressee_id=$1)`, [senderId, recipientId]);
                if (fCheck.rows.length > 0) {
                    friendshipStatus = fCheck.rows[0].status;
                    requesterId = fCheck.rows[0].requester_id;
                }
            } else {
                // Créer la conversation
                const newConv = await pool.query(
                    `INSERT INTO conversations (product_id, type, created_at, updated_at) 
                     VALUES ($1, 'private', NOW(), NOW()) 
                     RETURNING id`,
                    [productId]
                );
                conversationId = newConv.rows[0].id;

                // Ajouter les participants
                await pool.query(`
                    INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
                    VALUES ($1, $2, NOW()), ($1, $3, NOW())
                `, [conversationId, senderId, recipientId]);

                // Créer la relation d'amitié (Pending par défaut)
                // Si c'est lié à un achat direct, on pourrait mettre 'accepted', mais restons safe sur 'pending' sauf si logique métier contraire
                await pool.query(`
                    INSERT INTO friendships (requester_id, addressee_id, status) 
                    VALUES ($1, $2, 'pending') 
                    ON CONFLICT (requester_id, addressee_id) DO NOTHING
                `, [senderId, recipientId]);
            }
        }

        // 2. Insérer le message
        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, metadata) 
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [conversationId, senderId, content, type, metadata ? JSON.stringify(metadata) : null]
        );

        const newMessage = msgResult.rows[0];

        console.log(`✅ [BD] Message inséré:`, {
            id: newMessage.id,
            conversation_id: newMessage.conversation_id,
            sender_id: newMessage.sender_id,
        });

        // Objet complet à envoyer via socket
        const socketPayload = {
            ...newMessage,
            conversation_id: conversationId,
            friendship_status: friendshipStatus,
            requester_id: requesterId
        };

        // 3. ENVOI TEMPS RÉEL (SOCKET.IO)
        const io = req.app.get('io');
        if (io) {
            console.log(`📡 [SOCKET] Émission new_message vers user_${recipientId}`);
            // Envoyer au destinataire (pour sa liste et son chat)
            io.to(`user_${recipientId}`).emit('new_message', socketPayload);
            io.to(`user_${recipientId}`).emit('new_request', { sender_id: senderId, conversation_id: conversationId });
            console.log(`📡 [SOCKET] new_request émis vers user_${recipientId}`);

            // Envoyer à l'expéditeur (pour mettre à jour SA liste de discussions en temps réel aussi)
            io.to(`user_${senderId}`).emit('new_message', socketPayload);
        }

        res.json({
            success: true,
            message: newMessage,
            conversationId,
            friendship_status: friendshipStatus,
            requester_id: requesterId
        });

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

    console.log(`📨 [/messages] Expéditeur: ${senderId}, Contenu: "${content.substring(0, 50)}..."`);

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

        console.log(`👤 [/messages] Destinataire: ${recipientId}`);

        // 2. Insérer le message en BDD
        const msgResult = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, content, type, amount, reply_to_id, metadata) 
             VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
            [conversationId, senderId, content, type || 'text', amount, replyToId, metadata ? JSON.stringify(metadata) : null]
        );

        const newMessage = msgResult.rows[0];

        console.log(`✅ [BD] Message inséré (ID: ${newMessage.id}) dans conversation ${conversationId}`);

        // 3. ENVOI TEMPS RÉEL VIA SOCKET.IO (C'est ce qui manquait !)
        const io = req.app.get('io');
        if (io) {
            const socketPayload = {
                ...newMessage,
                conversation_id: conversationId,
                sender_id: senderId
            };
            // On envoie au destinataire
            console.log(`📡 [SOCKET] Émission new_message vers user_${recipientId}`);
            io.to(`user_${recipientId}`).emit('new_message', socketPayload);
            // On envoie aussi à l'expéditeur pour confirmer (optionnel mais recommandé pour multi-appareils)
            console.log(`📡 [SOCKET] Émission new_message vers user_${senderId} (confirmation)`);
            io.to(`user_${senderId}`).emit('new_message', socketPayload);
        }

        res.json({ success: true, message: newMessage });

    } catch (err) {
        console.error("Erreur envoi message:", err);
        res.status(500).json({ error: "Erreur lors de l'envoi" });
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

/**
 * GET /chat/messages/:otherUserId
 */
router.get('/messages/:otherUserId', async (req, res) => {
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
            ${cursorCondition}
            ORDER BY m.created_at DESC
            LIMIT $${paramIndex}
        `, params);

        if (result.rows.length > 0) {
            const convId = result.rows[0].conversation_id;
            await pool.query(
                "UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id = $2 AND is_read = false",
                [convId, otherUserId]
            );
        }

        const messages = result.rows.reverse();
        const nextCursor = result.rows.length === parseInt(limit)
            ? result.rows[result.rows.length - 1].id
            : null;

        res.json({
            messages,
            next_cursor: nextCursor,
            has_more: nextCursor !== null
        });
    } catch (err) {
        console.error("Erreur GET /chat/messages/:otherUserId:", err);
        res.status(500).json({ error: "Erreur récupération messages" });
    }
});

/**
 * GET /chat/users
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