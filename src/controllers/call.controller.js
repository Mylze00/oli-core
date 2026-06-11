const pool = require('../config/db');

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
