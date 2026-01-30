const avatarHistoryRepository = require('../repositories/avatar-history.repository');
const behaviorRepository = require('../repositories/behavior.repository');
const shopRepository = require('../repositories/shop.repository'); // Import ShopRepo
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

    // 1. Vérifier la limite de 30 changements
    const canUpdate = await checkAvatarChangeLimit(userId);
    if (!canUpdate) {
        throw new Error("Vous avez atteint la limite de 30 changements d'avatar.");
    }

    // 2. Créer l'enregistrement dans l'historique
    const avatarRecord = await avatarHistoryRepository.createAvatarRecord({
        userId,
        avatarUrl,
        storageProvider: metadata.storageProvider || 'cloudinary',
        fileSizeBytes: metadata.fileSizeBytes,
        mimeType: metadata.mimeType
    });

    // 3. Mettre à jour l'avatar dans la table users
    await pool.query(
        'UPDATE users SET avatar_url = $1 WHERE id = $2',
        [avatarUrl, userId]
    );

    // 4. Synchroniser avec les boutiques de l'utilisateur (logo_url = user avatar)
    // "l'avatar de la boutique seras le même que l'utilisateur va pouvoir utiliser pour sa page de profil"
    try {
        const userShops = await shopRepository.findByOwnerId(userId);
        if (userShops && userShops.length > 0) {
            for (const shop of userShops) {
                // On met à jour le logo_url de la boutique pour qu'il corresponde à l'avatar utilisateur
                // Note: Si on voulait uniquement utiliser l'avatar utilisateur sans dupliquer, 
                // on modifierait juste la requête GET shop, mais ici on assure la persistance.
                await pool.query('UPDATE shops SET logo_url = $1 WHERE id = $2', [avatarUrl, shop.id]);
            }
        }
    } catch (err) {
        console.error("Erreur sync avatar shops:", err);
        // On ne bloque pas tout pour ça
    }

    // 5. Tracker l'événement
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
 * Vérifier si l'utilisateur peut changer d'avatar (Max 30)
 */
async function checkAvatarChangeLimit(userId) {
    const history = await avatarHistoryRepository.getAvatarHistory(userId, 100); // Check enough history
    // "limiter à 30 fois"
    if (history.length >= 30) {
        return false;
    }
    return true;
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
    // Check limit also applies to restore? usually yes as it is a change
    const canUpdate = await checkAvatarChangeLimit(userId);
    if (!canUpdate) {
        throw new Error("Vous avez atteint la limite de 30 changements d'avatar.");
    }

    const restored = await avatarHistoryRepository.restoreAvatar(userId, avatarId);

    // Sync shops also on restore
    try {
        const userShops = await shopRepository.findByOwnerId(userId);
        if (userShops && userShops.length > 0) {
            for (const shop of userShops) {
                await pool.query('UPDATE shops SET logo_url = $1 WHERE id = $2', [restored.avatar_url, shop.id]);
            }
        }
    } catch (e) { console.error("Sync error restore", e); }

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
        byProvider,
        limitReached: history.length >= 30,
        changesLeft: Math.max(0, 30 - history.length)
    };
}

module.exports = {
    saveAvatar,
    getCurrentAvatar,
    getAvatarHistory,
    restorePreviousAvatar,
    deleteAvatarFromHistory,
    getStorageStats,
    checkAvatarChangeLimit
};
