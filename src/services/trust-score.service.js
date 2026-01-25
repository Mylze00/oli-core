const trustScoreRepository = require('../repositories/trust-score.repository');
const behaviorRepository = require('../repositories/behavior.repository');

/**
 * Service pour la gestion des trust scores
 */

/**
 * Récupérer le trust score d'un utilisateur
 */
async function getUserTrustScore(userId) {
    const score = await trustScoreRepository.findByUserId(userId);

    if (!score) {
        throw new Error('Trust score non trouvé');
    }

    return {
        ...score,
        riskLevel: interpretRiskLevel(score.fraud_risk_level),
        scoreInterpretation: interpretScore(score.overall_score)
    };
}

/**
 * Interpréter le niveau de risque
 */
function interpretRiskLevel(level) {
    const interpretations = {
        low: 'Utilisateur de confiance',
        medium: 'Surveillance recommandée',
        high: 'Risque élevé - Vérification requise',
        critical: 'Risque critique - Action immédiate requise'
    };

    return interpretations[level] || 'Inconnu';
}

/**
 * Interpréter le score global
 */
function interpretScore(score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Bon';
    if (score >= 40) return 'Moyen';
    if (score >= 20) return 'Faible';
    return 'Très faible';
}

/**
 * Mettre à jour le score de transaction après un achat
 */
async function updateAfterPurchase(userId, orderAmount, orderStatus) {
    const currentScore = await trustScoreRepository.findByUserId(userId);

    if (!currentScore) {
        throw new Error('Trust score non trouvé');
    }

    let newScore = currentScore.transaction_score;

    // Augmenter le score pour les achats réussis
    if (orderStatus === 'completed' && orderAmount > 0) {
        newScore = Math.min(100, newScore + 2);
    }

    // Diminuer le score pour les litiges
    if (orderStatus === 'disputed') {
        newScore = Math.max(0, newScore - 10);
    }

    await trustScoreRepository.updateTransactionScore(userId, newScore);

    // Recalculer le score global
    const updatedScore = await trustScoreRepository.recalculateOverallScore(userId);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'trust_score_updated',
        eventCategory: 'security',
        eventData: {
            reason: 'purchase',
            oldScore: currentScore.overall_score,
            newScore: updatedScore
        }
    });

    return updatedScore;
}

/**
 * Mettre à jour le score de comportement
 */
async function updateBehaviorScore(userId, adjustment, reason) {
    const currentScore = await trustScoreRepository.findByUserId(userId);

    if (!currentScore) {
        throw new Error('Trust score non trouvé');
    }

    const newScore = Math.max(0, Math.min(100, currentScore.behavior_score + adjustment));

    await trustScoreRepository.updateBehaviorScore(userId, newScore);

    // Recalculer le score global
    const updatedScore = await trustScoreRepository.recalculateOverallScore(userId);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'trust_score_updated',
        eventCategory: 'security',
        eventData: {
            reason,
            adjustment,
            oldScore: currentScore.overall_score,
            newScore: updatedScore
        }
    });

    return updatedScore;
}

/**
 * Signaler un utilisateur comme suspect
 */
async function flagUser(userId, reason, level = 'high') {
    await trustScoreRepository.updateFraudRiskLevel(userId, level, reason);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'user_flagged',
        eventCategory: 'security',
        eventData: { reason, level }
    });

    return await trustScoreRepository.findByUserId(userId);
}

/**
 * Récupérer les utilisateurs à risque
 */
async function getHighRiskUsers(limit = 50) {
    return await trustScoreRepository.findHighRiskUsers(limit);
}

/**
 * Récupérer les statistiques globales
 */
async function getTrustScoreStatistics() {
    const stats = await trustScoreRepository.getTrustScoreStats();

    return {
        averages: {
            overall: parseFloat(stats.avg_score),
            identity: parseFloat(stats.avg_identity),
            transaction: parseFloat(stats.avg_transaction),
            behavior: parseFloat(stats.avg_behavior),
            social: parseFloat(stats.avg_social)
        },
        riskDistribution: {
            low: parseInt(stats.low_risk_count),
            medium: parseInt(stats.medium_risk_count),
            high: parseInt(stats.high_risk_count),
            critical: parseInt(stats.critical_risk_count)
        },
        flaggedUsers: parseInt(stats.flagged_count)
    };
}

/**
 * Recalculer tous les scores d'un utilisateur
 */
async function recalculateUserScore(userId) {
    return await trustScoreRepository.recalculateOverallScore(userId);
}

module.exports = {
    getUserTrustScore,
    updateAfterPurchase,
    updateBehaviorScore,
    flagUser,
    getHighRiskUsers,
    getTrustScoreStatistics,
    recalculateUserScore
};
