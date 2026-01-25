const behaviorService = require('../services/behavior.service');

/**
 * Controller pour le tracking comportemental
 */

/**
 * Tracker un événement utilisateur
 * POST /api/behavior/track
 */
exports.trackEvent = async (req, res) => {
    try {
        const userId = req.user.id;
        const { eventType, eventCategory, data } = req.body;

        // Extraire le contexte de la requête
        const context = {
            sessionId: req.headers['x-session-id'],
            deviceType: req.headers['x-device-type'],
            platform: req.headers['x-platform'],
            ipAddress: req.ip || req.connection.remoteAddress,
            userAgent: req.headers['user-agent']
        };

        const event = await behaviorService.trackUserEvent(
            userId,
            { eventType, eventCategory, data },
            context
        );

        res.status(201).json({
            success: true,
            data: event
        });
    } catch (error) {
        console.error('Error tracking event:', error);
        res.status(400).json({
            success: false,
            message: error.message || 'Erreur lors du tracking de l\'événement'
        });
    }
};

/**
 * Récupérer l'historique d'événements de l'utilisateur
 * GET /api/behavior/my-history
 */
exports.getMyHistory = async (req, res) => {
    try {
        const userId = req.user.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 100;

        const events = await behaviorService.getUserEventHistory(userId, page, limit);

        res.json({
            success: true,
            data: events,
            pagination: { page, limit }
        });
    } catch (error) {
        console.error('Error getting event history:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération de l\'historique'
        });
    }
};

/**
 * Analyser le comportement de l'utilisateur
 * GET /api/behavior/my-analysis
 */
exports.getMyAnalysis = async (req, res) => {
    try {
        const userId = req.user.id;
        const days = parseInt(req.query.days) || 30;

        const analysis = await behaviorService.analyzeUserBehavior(userId, days);

        res.json({
            success: true,
            data: analysis
        });
    } catch (error) {
        console.error('Error analyzing behavior:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de l\'analyse du comportement'
        });
    }
};

/**
 * Récupérer les statistiques d'événements (Admin)
 * GET /api/behavior/statistics
 */
exports.getStatistics = async (req, res) => {
    try {
        const days = parseInt(req.query.days) || 7;
        const stats = await behaviorService.getEventStatistics(days);

        res.json({
            success: true,
            data: stats
        });
    } catch (error) {
        console.error('Error getting event statistics:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la récupération des statistiques'
        });
    }
};
