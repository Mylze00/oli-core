const verificationRepository = require('../repositories/verification.repository');
const behaviorRepository = require('../repositories/behavior.repository');

/**
 * Service pour la gestion des niveaux de vérification
 */

/**
 * Récupérer le niveau de vérification d'un utilisateur
 */
async function getVerificationLevel(userId) {
    const level = await verificationRepository.findByUserId(userId);

    if (!level) {
        throw new Error('Niveau de vérification non trouvé');
    }

    return {
        ...level,
        verificationPercentage: calculateVerificationPercentage(level)
    };
}

/**
 * Calculer le pourcentage de vérification
 */
function calculateVerificationPercentage(level) {
    let count = 0;
    if (level.phone_verified) count++;
    if (level.email_verified) count++;
    if (level.identity_verified) count++;
    if (level.address_verified) count++;

    return Math.round((count / 4) * 100);
}

/**
 * Vérifier l'email d'un utilisateur
 */
async function verifyEmail(userId) {
    const updated = await verificationRepository.updateEmailVerification(userId, true);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'email_verified',
        eventCategory: 'security',
        eventData: { verificationLevel: updated.verification_level }
    });

    return updated;
}

/**
 * Vérifier une adresse
 */
async function verifyAddress(userId) {
    const updated = await verificationRepository.updateAddressVerification(userId, true);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'address_verified',
        eventCategory: 'security',
        eventData: { verificationLevel: updated.verification_level }
    });

    return updated;
}

/**
 * Récupérer les statistiques de vérification
 */
async function getVerificationStatistics() {
    const stats = await verificationRepository.getVerificationStats();

    const total = stats.reduce((sum, stat) => sum + parseInt(stat.count), 0);

    return {
        total,
        byLevel: stats,
        summary: {
            verified: stats
                .filter(s => ['premium', 'advanced', 'intermediate'].includes(s.verification_level))
                .reduce((sum, s) => sum + parseInt(s.count), 0),
            unverified: stats
                .filter(s => ['basic', 'unverified'].includes(s.verification_level))
                .reduce((sum, s) => sum + parseInt(s.count), 0)
        }
    };
}

/**
 * Récupérer les utilisateurs par niveau
 */
async function getUsersByLevel(level, page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    return await verificationRepository.findByVerificationLevel(level, limit, offset);
}

module.exports = {
    getVerificationLevel,
    verifyEmail,
    verifyAddress,
    getVerificationStatistics,
    getUsersByLevel
};
