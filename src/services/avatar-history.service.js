const avatarHistoryRepository = require('../repositories/avatar-history.repository');
const behaviorRepository = require('../repositories/behavior.repository');
const pool = require('../config/db');

/**
 * Service pour la gestion de l'historique des avatars
 */

/**
 * Enregistrer un nouvel avatar
 */
async function saveAvatar(userId, avatarUrl, metadata = {}) {
    // Validation
    if (!avatarUrl) {
        throw new Error('URL de l\'avatar requise');
    }

    // Créer l'enregistrement dans l'historique
    const avatarRecord = await avatarHistoryRepository.createAvatarRecord({
        userId,
        avatarUrl,
        storageProvider: metadata.storageProvider || 'cloudinary',
        fileSizeBytes: metadata.fileSizeBytes,
        mimeType: metadata.mimeType
    });

    // Mettre à jour l'avatar dans la table users
    await pool.query(
        'UPDATE users SET avatar_url = $1 WHERE id = $2',
        [avatarUrl, userId]
    );

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'avatar_updated',
        eventCategory: 'engagement',
        eventData: {
            avatarId: avatarRecord.id,
            storageProvider: avatarRecord.storage_provider
        }
    });

    return avatarRecord;
}

/**
 * Récupérer l'avatar actuel
 */
async function getCurrentAvatar(userId) {
    const avatar = await avatarHistoryRepository.getCurrentAvatar(userId);

    if (!avatar) {
        return null;
    }

    return avatar;
}

/**
 * Récupérer l'historique des avatars
 */
async function getAvatarHistory(userId, limit = 10) {
    return await avatarHistoryRepository.getAvatarHistory(userId, limit);
}

/**
 * Restaurer un avatar précédent
 */
async function restorePreviousAvatar(userId, avatarId) {
    const restored = await avatarHistoryRepository.restoreAvatar(userId, avatarId);

    // Tracker l'événement
    await behaviorRepository.trackEvent({
        userId,
        eventType: 'avatar_restored',
        eventCategory: 'engagement',
        eventData: { avatarId }
    });

    return restored;
}

/**
 * Supprimer un avatar de l'historique
 */
async function deleteAvatarFromHistory(userId, avatarId) {
    const deleted = await avatarHistoryRepository.deleteAvatar(userId, avatarId);

    if (!deleted) {
        throw new Error('Avatar non trouvé ou impossible de supprimer l\'avatar actuel');
    }

    return deleted;
}

/**
 * Obtenir les statistiques d'utilisation du stockage
 */
async function getStorageStats(userId) {
    const history = await avatarHistoryRepository.getAvatarHistory(userId, 100);

    const totalSize = history.reduce((sum, avatar) => sum + (avatar.file_size_bytes || 0), 0);
    const byProvider = history.reduce((acc, avatar) => {
        const provider = avatar.storage_provider || 'unknown';
        acc[provider] = (acc[provider] || 0) + 1;
        return acc;
    }, {});

    return {
        totalAvatars: history.length,
        totalSizeBytes: totalSize,
        totalSizeMB: (totalSize / (1024 * 1024)).toFixed(2),
        byProvider
    };
}

module.exports = {
    saveAvatar,
    getCurrentAvatar,
    getAvatarHistory,
    restorePreviousAvatar,
    deleteAvatarFromHistory,
    getStorageStats
};
