const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// --- CONFIGURATION UPLOAD (IMAGES) ---
const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
    destination: (req, file, cb) => { cb(null, uploadDir); },
    filename: (req, file, cb) => {
        const cleanName = file.originalname.replace(/[^\w.]+/g, '_');
        cb(null, 'chat-' + Date.now() + '-' + cleanName);
    }
});
const upload = multer({ storage: storage, limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB max

// --- ROUTES ---

// 0. Upload d'image de chat
router.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) return res.status(400).json({ error: "Pas de fichier" });

    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const imageUrl = `${protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    res.json({ url: imageUrl });
});

// --- MIDDLEWARE : Vérifier si on peut parler (Friendship/Request logic) ---
async function canSendMessage(senderId, recipientId) {
    const res = await pool.query(
        "SELECT * FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
        [senderId, recipientId]
    );

    if (res.rows.length === 0) return { allowed: true, isNewRequest: true };

    const friendship = res.rows[0];
    if (friendship.status === 'accepted') return { allowed: true, isNewRequest: false };

    // Si c'est 'pending'
    if (friendship.status === 'pending') {
        // S'il est l'addressee (celui qui a reçu l'invit), il peut répondre (ce qui va accepter l'invit)
        if (friendship.addressee_id === senderId) return { allowed: true, isNewRequest: false };

        // S'il est le requester, on autorise quelques messages pour donner des détails (ex: 3)
        const msgCheck = await pool.query(
            "SELECT COUNT(*) FROM messages m JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id WHERE cp.user_id = $1 AND m.sender_id = $1 AND cp.conversation_id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = $2)",
            [senderId, recipientId]
        );

        if (parseInt(msgCheck.rows[0].count) >= 3) {
            return { allowed: false, error: "Limite de messages atteinte. Attendez que le destinataire réponde pour continuer." };
        }

        return { allowed: true, isNewRequest: false };
    }

    return { allowed: false, error: "Vous n'êtes pas autorisé à envoyer de message." };
}

// 1. Envoyer une demande / un premier message
router.post('/request', async (req, res) => {
    const { recipientId, content, type, productId } = req.body;
    const senderId = req.user.id;

    try {
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

        // Check relation
        const relCheck = await pool.query(
            "SELECT * FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
            [senderId, recipientId]
        );

        if (relCheck.rows.length === 0) {
            await pool.query(
                "INSERT INTO friendships (requester_id, addressee_id, status) VALUES ($1, $2, 'pending')",
                [senderId, recipientId]
            );
        }

        // Create Conv
        const convRes = await pool.query(
            "INSERT INTO conversations (type, product_id) VALUES ('private', $1) RETURNING id",
            [productId || null]
        );
        const convId = convRes.rows[0].id;

        await pool.query("INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1, $2), ($1, $3)", [convId, senderId, recipientId]);

        // Insert Message
        const msgRes = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, type, content) VALUES ($1, $2, $3, $4) RETURNING *",
            [convId, senderId, type || 'text', content]
        );

        const io = req.app.get('io');
        if (io) {
            io.to(`user_${recipientId}`).emit('new_request', {
                from: req.user,
                message: msgRes.rows[0],
                conversationId: convId
            });
        }

        res.json({ success: true, message: msgRes.rows[0] });

    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur serveur" });
    }
});

// 2. Accepter une demande
router.post('/accept', async (req, res) => {
    const { requesterId } = req.body;
    const addresseeId = req.user.id;

    try {
        await pool.query(
            "UPDATE friendships SET status = 'accepted' WHERE requester_id = $1 AND addressee_id = $2",
            [requesterId, addresseeId]
        );

        // Optionnel: Envoyer un signal socket aux deux pour décoincer l'UI
        const io = req.app.get('io');
        if (io) {
            io.to(`user_${requesterId}`).emit('request_accepted', { by: addresseeId });
        }

        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur acceptation" });
    }
});

// 3. Envoyer un message (Flow normal)
router.post('/messages', async (req, res) => {
    const { conversationId, recipientId, content, type, amount, replyToId } = req.body;
    const senderId = req.user.id;

    try {
        // --- VÉRIFICATION PERMISSIONS ---
        const check = await canSendMessage(senderId, recipientId);
        if (!check.allowed) {
            return res.status(403).json({ error: check.error });
        }

        // Si c'est le destinataire qui répond, on accepte automatiquement la demande
        const relRes = await pool.query(
            "SELECT * FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
            [senderId, recipientId]
        );

        if (relRes.rows.length > 0) {
            const rel = relRes.rows[0];
            if (rel.status === 'pending' && rel.addressee_id === senderId) {
                await pool.query("UPDATE friendships SET status = 'accepted' WHERE id = $1", [rel.id]);
                console.log(`✅ Relation ${rel.id} auto-acceptée par réponse de l'addressee ${senderId}`);
            }
        }

        // Insertion avec reply_to_id
        const msgRes = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, type, content, amount, reply_to_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
            [conversationId, senderId, type || 'text', content, amount, replyToId || null]
        );

        // Récupérer le contenu du parent si replyToId existe
        let fullMessage = msgRes.rows[0];
        if (replyToId) {
            const parentRes = await pool.query("SELECT content FROM messages WHERE id = $1", [replyToId]);
            if (parentRes.rows.length > 0) {
                fullMessage.reply_to_content = parentRes.rows[0].content;
            }
        }

        const io = req.app.get('io');
        if (io && recipientId) {
            io.to(`user_${recipientId}`).emit('new_message', fullMessage);
        }

        res.json(fullMessage);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur envoi" });
    }
});

// 4. Récupérer mes conversations
router.get('/conversations', async (req, res) => {
    const myId = req.user.id;
    const query = `
        SELECT c.id as conversation_id, 
               u.name as other_name, u.avatar_url as other_avatar, u.id as other_id, u.phone as other_phone,
               m.content as last_message, m.created_at as last_time,
               p.id as product_id, p.name as product_name, p.price as product_price,
               p.images as product_images_raw,
               f.status as friendship_status, f.requester_id
        FROM conversation_participants cp
        JOIN conversations c ON cp.conversation_id = c.id
        JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
        JOIN users u ON cp2.user_id = u.id
        LEFT JOIN friendships f ON (f.requester_id = cp.user_id AND f.addressee_id = cp2.user_id) 
                                OR (f.requester_id = cp2.user_id AND f.addressee_id = cp.user_id)
        LEFT JOIN products p ON c.product_id = p.id
        LEFT JOIN LATERAL (
            SELECT content, created_at FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1
        ) m ON true
        WHERE cp.user_id = $1
        ORDER BY m.created_at DESC NULLS LAST
    `;

    try {
        const result = await pool.query(query, [myId]);

        // Post-traitement pour l'image produit (car stockée en array/string dans products)
        const conversations = result.rows.map(row => {
            let imgUrl = null;
            if (row.product_images_raw) {
                let imgs = [];
                // PostgreSQL retourne un array directement si le drivers est bien configuré, sinon string
                if (Array.isArray(row.product_images_raw)) imgs = row.product_images_raw;
                else if (typeof row.product_images_raw === 'string') {
                    imgs = row.product_images_raw.replace(/[{}"]/g, '').split(',');
                }

                if (imgs.length > 0 && imgs[0]) {
                    if (imgs[0].startsWith('http')) imgUrl = imgs[0];
                    else imgUrl = `https://oli-core.onrender.com/uploads/${imgs[0]}`;
                }
            }

            return {
                ...row,
                product_image: imgUrl, // On expose le champ attendu par le frontend
                product_images_raw: undefined // On nettoie
            };
        });

        res.json(conversations);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur" });
    }
});

// 5. Récupérer l'historique de messages avec un user
router.get('/messages/:otherUserId', async (req, res) => {
    const myId = req.user.id;
    const { otherUserId } = req.params;
    const { productId } = req.query;

    try {
        let conversationFilter = "";
        const params = [myId, otherUserId];

        if (productId) {
            conversationFilter = `AND c.product_id = $3`;
            params.push(productId);
        }

        const query = `
            SELECT m.*, u.name as sender_name, u.phone as sender_phone, c.product_id, c.id as conversation_id,
                   parent.content as reply_to_content, parent.sender_id as reply_to_sender,
                   f.status as friendship_status, f.requester_id
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
        `;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur récupération messages" });
    }
});

// 6. Rechercher des utilisateurs
router.get('/users', async (req, res) => {
    const { q } = req.query;
    const myId = req.user.id;

    if (!q || q.length < 2) return res.json([]);

    try {
        const result = await pool.query(
            "SELECT id, name, avatar_url, phone FROM users WHERE (name ILIKE $1 OR phone ILIKE $1) AND id != $2 LIMIT 20",
            [`%${q}%`, myId]
        );
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur recherche" });
    }
});

module.exports = router;
