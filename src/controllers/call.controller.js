const pool = require('../config/db');
const callLogService = require('../services/call-log.service');

/** Refus depuis l'écran natif, quand l'application n'a pas de connexion en direct. */
exports.declineCall = async (req, res) => {
    const { callerId } = req.params;
    if (!/^\d+$/.test(callerId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        await callLogService.updateCallStatus(callerId, req.user.id, 'rejected');
        const io = req.app.get('io');
        if (io) io.to(`user_${callerId}`).emit('webrtc_call_rejected', { fromId: req.user.id });
        res.json({ success: true });
    } catch (err) {
        console.error('Erreur declineCall:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
};

exports.getCallPeer = async (req, res) => {
    const { userId } = req.params;
    if (!/^\d+$/.test(userId)) {
        return res.status(400).json({ error: 'Requête invalide' });
    }

    try {
        const identity = await callLogService.getCallIdentity(userId);
        if (!identity) return res.status(404).json({ error: 'Utilisateur introuvable' });
        res.json(identity);
    } catch (err) {
        console.error('Erreur getCallPeer:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
};

exports.getCallHistory = async (req, res) => {
    const myId = req.user.id;
    try {
        const result = await pool.query(`
            SELECT c.*, 
                u.name as other_name, 
                u.avatar_url as other_avatar, 
                u.phone as other_phone
            FROM call_logs c
            JOIN users u ON (c.caller_id = u.id OR c.receiver_id = u.id) AND u.id != $1
            WHERE c.caller_id = $1 OR c.receiver_id = $1
            ORDER BY c.created_at DESC
        `, [myId]);

        res.json(result.rows);
    } catch (err) {
        console.error("Erreur getCallHistory:", err);
        res.status(500).json({ error: "Erreur serveur" });
    }
};
