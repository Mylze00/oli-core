const trustScoreService = require('../services/trust-score.service');

/**
 * Controller pour la gestion des trust scores
 */

/**
 * Récupérer le trust score de l'utilisateur
 * GET /api/trust-score/my-score
 */
exports.getMyTrustScore = async (req, res) => {
    try {
        const userId = req.user.id;
        const score = await trustScoreService.getUserTrustScore(userId);

        res.json({
            success: true,
            data: score
        });
    } catch (error) {
        console.error('Error getting trust score:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Erreur lors de la récupération du trust score'
        });
    }
};

/**
 * Récupérer les statistiques globales (Admin)
 * GET /api/trust-score/statistics
 */
exports.getStatistics = async (req, res) => {
    try {
        const stats = await trustScoreService.getTrustScoreStatistics();

        res.json({
            success: true,
            data: stats
        });
    } catch (error) {
        console.error('Error getting trust score statistics:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des statistiques'
        });
    }
};

/**
 * Récupérer les utilisateurs à risque (Admin)
 * GET /api/trust-score/high-risk-users
 */
exports.getHighRiskUsers = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 50;
        const users = await trustScoreService.getHighRiskUsers(limit);

        res.json({
            success: true,
            data: users
        });
    } catch (error) {
        console.error('Error getting high risk users:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des utilisateurs à risque'
        });
    }
};

/**
 * Signaler un utilisateur (Admin)
 * POST /api/trust-score/:userId/flag
 */
exports.flagUser = async (req, res) => {
    try {
        const { userId } = req.params;
        const { reason, level } = req.body;

        if (!reason) {
            return res.status(400).json({
                success: false,
                message: 'La raison est requise'
            });
        }

        const score = await trustScoreService.flagUser(userId, reason, level || 'high');

        res.json({
            success: true,
            message: 'Utilisateur signalé avec succès',
            data: score
        });
    } catch (error) {
        console.error('Error flagging user:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Erreur lors du signalement de l\'utilisateur'
        });
    }
};
