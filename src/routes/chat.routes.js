const express = require('express');
const router = express.Router();
const pool = require('../config/db');

// --- MIDDLEWARE : Vérifier si on peut parler (Friendship/Request logic) ---
async function canSendMessage(senderId, recipientId) {
    // 1. Chercher si une relation existe
    const res = await pool.query(
        "SELECT * FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
        [senderId, recipientId]
    );

    // 2. Si aucune relation => C'est une NOUVELLE DEMANDE (autorisé si pas bloqué)
    if (res.rows.length === 0) return { allowed: true, isNewRequest: true };

    const friendship = res.rows[0];

    // 3. Si accepté => OK
    if (friendship.status === 'accepted') return { allowed: true, isNewRequest: false };

    // 4. Si 'pending', seul celui qui a REÇU la demande peut répondre (accepter) ou le demandeur ne peut pas en renvoyer plein.
    // Pour simplifier : tant que c'est pending, on considère que la conversation est en mode "Attente".
    // L'utilisateur veut "limiter à 1 message avec acceptation".
    // Donc si 'pending' existe, on bloque l'envoi de NOUVEAUX messages S'IL Y EN A DÉJÀ UN.
    // On vérifiera s'il y a déjà des messages.
    return { allowed: false, error: "En attente d'acceptation" };
}

// 1. Envoyer une demande / un premier message
router.post('/request', async (req, res) => {
    // req.user est défini grâce au middleware dans server.js
    const { recipientId, content, type } = req.body; // type: text, image, voice...
    const senderId = req.user.id;

    try {
        // A. Vérifier existence relation
        const relCheck = await pool.query(
            "SELECT * FROM friendships WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
            [senderId, recipientId]
        );

        if (relCheck.rows.length > 0) {
            return res.status(400).json({ error: "Une relation existe déjà avec cet utilisateur. Utilisez la route standard." });
        }

        // B. Créer la relation 'pending'
        await pool.query(
            "INSERT INTO friendships (requester_id, addressee_id, status) VALUES ($1, $2, 'pending')",
            [senderId, recipientId]
        );

        // C. Créer ou trouver une conversation (privée)
        // Vérifier si conversation existe déjà (au cas où vieux data)
        let convId;
        // ... (Logique création conv complexe, on simplifie : on crée une conv pour ces 2 users)
        const convRes = await pool.query("INSERT INTO conversations (type) VALUES ('private') RETURNING id");
        convId = convRes.rows[0].id;

        // Ajouter participants
        await pool.query("INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1, $2), ($1, $3)", [convId, senderId, recipientId]);

        // D. Insérer le message
        const msgRes = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, type, content) VALUES ($1, $2, $3, $4) RETURNING *",
            [convId, senderId, type || 'text', content]
        );

        // E. Emit Socket (Si dispo)
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
    const myId = req.user.id;

    try {
        await pool.query(
            "UPDATE friendships SET status = 'accepted' WHERE requester_id = $1 AND addressee_id = $2",
            [requesterId, myId]
        );
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: "Erreur" });
    }
});

// 3. Envoyer un message (Flow normal)
router.post('/messages', async (req, res) => {
    const { conversationId, recipientId, content, type, amount } = req.body;
    const senderId = req.user.id;

    // TODO: Vérifier permissions (friendships accepted)

    try {
        const msgRes = await pool.query(
            "INSERT INTO messages (conversation_id, sender_id, type, content, amount) VALUES ($1, $2, $3, $4, $5) RETURNING *",
            [conversationId, senderId, type || 'text', content, amount]
        );

        const io = req.app.get('io');
        if (io && recipientId) {
            io.to(`user_${recipientId}`).emit('new_message', msgRes.rows[0]);
        }

        res.json(msgRes.rows[0]);
    } catch (err) {
        res.status(500).json({ error: "Erreur envoi" });
    }
});

// 4. Récupérer mes conversations
router.get('/conversations', async (req, res) => {
    const myId = req.user.id;
    // Query complexe pour récupérer dernier message + info user
    const query = `
        SELECT c.id as conversation_id, u.name as other_name, u.avatar_url as other_avatar, u.id as other_id,
        m.content as last_message, m.created_at as last_time
        FROM conversation_participants cp
        JOIN conversations c ON cp.conversation_id = c.id
        JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id != $1
        JOIN users u ON cp2.user_id = u.id
        LEFT JOIN LATERAL (
            SELECT content, created_at FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1
        ) m ON true
        WHERE cp.user_id = $1
    `;

    try {
        const result = await pool.query(query, [myId]);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur" });
    }
});

// 5. Récupérer l'historique de messages avec un user
router.get('/messages/:otherUserId', async (req, res) => {
    const myId = req.user.id;
    const { otherUserId } = req.params;

    try {
        // Obtenir l'ID de conversation
        // On pourrait le passer en param, mais c'est plus sûr de le déduire ou de vérifier
        // Simple query pour choper les messages entre ces 2 users
        // On suppose conversation_participants lie les 2.

        const query = `
            SELECT m.*, u.name as sender_name 
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            WHERE m.conversation_id IN (
                SELECT cp1.conversation_id 
                FROM conversation_participants cp1
                JOIN conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
                WHERE cp1.user_id = $1 AND cp2.user_id = $2
            )
            ORDER BY m.created_at ASC
        `;

        const result = await pool.query(query, [myId, otherUserId]);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Erreur récupération messages" });
    }
});

// 6. Rechercher des utilisateurs (pour démarrer une conversation)
router.get('/users', async (req, res) => {
    const { q } = req.query;
    const myId = req.user.id;

    if (!q || q.length < 2) return res.json([]); // Minimum 2 caractères

    try {
        // Recherche par nom ou téléphone (sauf soi-même)
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
