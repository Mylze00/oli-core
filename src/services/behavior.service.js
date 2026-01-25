const behaviorRepository = require('../repositories/behavior.repository');

/**
 * Service pour le tracking comportemental
 */

/**
 * Tracker un événement utilisateur
 */
async function trackUserEvent(userId, eventData, context = {}) {
    // Validation
    if (!eventData.eventType) {
        throw new Error('Type d\'événement requis');
    }

    // Déterminer la catégorie automatiquement si non fournie
    const category = eventData.eventCategory || categorizeEvent(eventData.eventType);

    const event = await behaviorRepository.trackEvent({
        userId,
        eventType: eventData.eventType,
        eventCategory: category,
        eventData: eventData.data || {},
        sessionId: context.sessionId,
        deviceType: context.deviceType,
        platform: context.platform,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        latitude: context.latitude,
        longitude: context.longitude,
        city: context.city,
        country: context.country
    });

    return event;
}

/**
 * Catégoriser automatiquement un événement
 */
function categorizeEvent(eventType) {
    const categories = {
        engagement: ['product_view', 'product_search', 'category_browse', 'profile_view'],
        transaction: ['add_to_cart', 'purchase', 'payment', 'order_placed'],
        social: ['message_sent', 'message_received', 'friend_request', 'follow'],
        security: ['login', 'logout', 'password_change', 'document_submitted']
    };

    for (const [category, types] of Object.entries(categories)) {
        if (types.includes(eventType)) {
            return category;
        }
    }

    return 'other';
}

/**
 * Récupérer l'historique d'événements d'un utilisateur
 */
async function getUserEventHistory(userId, page = 1, limit = 100) {
    const offset = (page - 1) * limit;
    return await behaviorRepository.findByUserId(userId, limit, offset);
}

/**
 * Récupérer les statistiques d'événements
 */
async function getEventStatistics(days = 7) {
    const stats = await behaviorRepository.getEventStats(days);

    return {
        period: `${days} derniers jours`,
        totalEvents: stats.reduce((sum, s) => sum + parseInt(s.count), 0),
        uniqueUsers: Math.max(...stats.map(s => parseInt(s.unique_users))),
        byType: stats.map(s => ({
            eventType: s.event_type,
            category: s.event_category,
            count: parseInt(s.count),
            uniqueUsers: parseInt(s.unique_users)
        }))
    };
}

/**
 * Récupérer les événements d'une session
 */
async function getSessionEvents(sessionId) {
    return await behaviorRepository.findBySessionId(sessionId);
}

/**
 * Analyser le comportement d'un utilisateur
 */
async function analyzeUserBehavior(userId, days = 30) {
    const productViews = await behaviorRepository.countUserEventsByType(userId, 'product_view', days);
    const purchases = await behaviorRepository.countUserEventsByType(userId, 'purchase', days);
    const messages = await behaviorRepository.countUserEventsByType(userId, 'message_sent', days);

    return {
        period: `${days} derniers jours`,
        engagement: {
            productViews,
            purchases,
            messages,
            conversionRate: productViews > 0 ? ((purchases / productViews) * 100).toFixed(2) : 0
        },
        activityLevel: calculateActivityLevel(productViews, purchases, messages)
    };
}

/**
 * Calculer le niveau d'activité
 */
function calculateActivityLevel(views, purchases, messages) {
    const totalActivity = views + (purchases * 5) + (messages * 2);

    if (totalActivity > 100) return 'very_high';
    if (totalActivity > 50) return 'high';
    if (totalActivity > 20) return 'medium';
    if (totalActivity > 5) return 'low';
    return 'very_low';
}

module.exports = {
    trackUserEvent,
    getUserEventHistory,
    getEventStatistics,
    getSessionEvents,
    analyzeUserBehavior
};
