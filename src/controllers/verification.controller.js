const verificationService = require('../services/verification.service');

/**
 * Controller pour la gestion des niveaux de vérification
 */

/**
 * Récupérer le niveau de vérification de l'utilisateur
 * GET /api/verification/my-level
 */
exports.getMyVerificationLevel = async (req, res) => {
    try {
        const userId = req.user.id;
        const level = await verificationService.getVerificationLevel(userId);

        res.json({
            success: true,
            data: level
        });
    } catch (error) {
        console.error('Error getting verification level:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Erreur lors de la récupération du niveau de vérification'
        });
    }
};

/**
 * Récupérer les statistiques de vérification (Admin)
 * GET /api/verification/statistics
 */
exports.getStatistics = async (req, res) => {
    try {
        const stats = await verificationService.getVerificationStatistics();

        res.json({
            success: true,
            data: stats
        });
    } catch (error) {
        console.error('Error getting verification statistics:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des statistiques'
        });
    }
};

/**
 * Récupérer les utilisateurs par niveau (Admin)
 * GET /api/verification/users-by-level/:level
 */
exports.getUsersByLevel = async (req, res) => {
    try {
        const { level } = req.params;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;

        const users = await verificationService.getUsersByLevel(level, page, limit);

        res.json({
            success: true,
            data: users,
            pagination: { page, limit }
        });
    } catch (error) {
        console.error('Error getting users by level:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des utilisateurs'
        });
    }
};
