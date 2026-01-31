const pool = require('../../config/db');

/**
 * Get all users with a subscription (Certified or Enterprise)
 * TODO: Filter by status 'pending' if we implement manual approval flow later
 */
exports.getAllVerifications = async (req, res) => {
    try {
        const query = `
            SELECT id, name, phone, subscription_plan, subscription_status, subscription_end_date, account_type, is_verified, avatar_url
            FROM users 
            WHERE subscription_plan != 'none' AND subscription_plan IS NOT NULL
            ORDER BY updated_at DESC
        `;
        const { rows } = await pool.query(query);
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: "Erreur serveur récupération vérifications" });
    }
};

/**
 * Manually revoke verification
 */
exports.revokeVerification = async (req, res) => {
    try {
        const { userId } = req.params;
        await pool.query(`
            UPDATE users 
            SET subscription_status = 'revoked', 
                is_verified = false,
                account_type = 'ordinaire'
            WHERE id = $1
        `, [userId]);
        res.json({ message: "Certification révoquée" });
    } catch (error) {
        res.status(500).json({ message: "Erreur révocation" });
    }
};
