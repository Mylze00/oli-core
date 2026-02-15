const pool = require('../../config/db');
const subscriptionService = require('../../services/subscription.service');

/**
 * GET /admin/verifications
 * Tous les utilisateurs certifiés actifs
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
 * GET /admin/verifications/pending
 * Demandes de certification en attente de validation
 */
exports.getPendingRequests = async (req, res) => {
    try {
        const requests = await subscriptionService.getPendingRequests();
        res.json(requests);
    } catch (error) {
        console.error('Error GET /admin/verifications/pending:', error);
        res.status(500).json({ message: "Erreur récupération demandes" });
    }
};

/**
 * GET /admin/verifications/all
 * Toutes les demandes (avec filtre optionnel ?status=pending|approved|rejected)
 */
exports.getAllRequests = async (req, res) => {
    try {
        const { status } = req.query;
        const requests = await subscriptionService.getAllRequests(status || null);
        res.json(requests);
    } catch (error) {
        console.error('Error GET /admin/verifications/all:', error);
        res.status(500).json({ message: "Erreur récupération demandes" });
    }
};

/**
 * POST /admin/verifications/:id/approve
 * Approuver une demande → upgrade l'utilisateur
 */
exports.approveRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const adminId = req.user.id;

        const result = await subscriptionService.approveRequest(parseInt(id), adminId);

        res.json({
            message: "Certification approuvée ✅",
            ...result
        });
    } catch (error) {
        console.error('Error POST /admin/verifications/:id/approve:', error);
        res.status(400).json({ message: error.message });
    }
};

/**
 * POST /admin/verifications/:id/reject
 * Rejeter une demande avec raison
 */
exports.rejectRequest = async (req, res) => {
    try {
        const { id } = req.params;
        const adminId = req.user.id;
        const { reason } = req.body;

        const result = await subscriptionService.rejectRequest(parseInt(id), adminId, reason);

        res.json({
            message: "Certification rejetée ❌",
            ...result
        });
    } catch (error) {
        console.error('Error POST /admin/verifications/:id/reject:', error);
        res.status(400).json({ message: error.message });
    }
};

/**
 * POST /admin/verifications/:userId/revoke
 * Révoquer manuellement une certification
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
