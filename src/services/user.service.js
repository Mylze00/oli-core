/**
 * Service User - Gestion du profil et activité utilisateur
 */
const userRepository = require('../repositories/user.repository');
const pool = require('../config/db'); // Needed for direct updates if repo doesn't support it yet
const { BASE_URL } = require('../config');

/**
 * Récupère les produits visités par un utilisateur
 * @param {number} userId - ID de l'utilisateur
 * @param {number} limit - Nombre maximum de produits à retourner (défaut: 20)
 * @returns {Promise<Array>} Liste des produits visités avec leurs infos
 */
async function getVisitedProducts(userId, limit = 20) {
    try {
        const productsRaw = await userRepository.findVisitedProducts(userId, limit);

        // Formater les résultats avec imageUrl
        return productsRaw.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}"]/g, '').split(',').filter(Boolean);
            }

            const imageUrls = imgs.map(img => {
                if (!img) return null;
                if (img.startsWith('http')) return img;
                return `${BASE_URL}/uploads/${img}`;
            }).filter(url => url !== null);

            return {
                ...p,
                imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
                images: imageUrls
            };
        });
    } catch (error) {
        console.error('Erreur getVisitedProducts:', error);
        throw new Error('Erreur lors de la récupération des produits visités');
    }
}

/**
 * Enregistre une vue de produit
 * @param {number} userId - ID de l'utilisateur
 * @param {number} productId - ID du produit
 * @returns {Promise<void>}
 */
async function trackProductView(userId, productId) {
    try {
        await userRepository.trackProductView(userId, productId);
    } catch (error) {
        console.error('Erreur trackProductView:', error);
        // Fail silently
    }
}

/**
 * Met à jour le nom d'un utilisateur
 * @param {number} userId - ID de l'utilisateur
 * @param {string} newName - Nouveau nom
 * @returns {Promise<Object>} Utilisateur mis à jour
 */
async function updateUserName(userId, newName) {
    if (!newName || newName.trim().length < 2) {
        throw new Error('Le nom doit contenir au moins 2 caractères');
    }

    if (newName.length > 100) {
        throw new Error('Le nom ne peut pas dépasser 100 caractères');
    }

    try {
        /*
        // 1. Check last update time
        const user = await userRepository.findById(userId);
        if (user && user.last_profile_update) {
            const twoWeeksAgo = new Date();
            twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

            if (new Date(user.last_profile_update) > twoWeeksAgo) {
                throw new Error('Vous ne pouvez modifier votre nom qu\'une fois toutes les 2 semaines.');
            }
        }
        */

        const updatedUser = await userRepository.updateName(userId, newName.trim());
        if (!updatedUser) {
            throw new Error('Utilisateur non trouvé');
        }

        return updatedUser;
    } catch (error) {
        console.error('Erreur updateUserName:', error);
        throw error;
    }
}

module.exports = {
    getVisitedProducts,
    trackProductView,
    updateUserName,
    updateProfile,
    uploadAvatar
};

/**
 * Met à jour le profil (nom)
 * @param {string} phone 
 * @param {string} name 
 * @returns 
 */
async function updateProfile(phone, name) {
    try {
        const result = await pool.query(
            "UPDATE users SET name = $1, last_profile_update = NOW(), updated_at = NOW() WHERE phone = $2 RETURNING *",
            [name, phone]
        );
        return result.rows[0];
    } catch (e) {
        throw e;
    }
}

/**
 * Met à jour l'avatar
 * @param {string} phone 
 * @param {string} avatarUrl 
 * @returns 
 */
async function uploadAvatar(phone, avatarUrl) {
    console.log("   [UserService.uploadAvatar] Début");
    console.log("   [UserService.uploadAvatar] Phone:", phone);
    console.log("   [UserService.uploadAvatar] Avatar URL:", avatarUrl);

    try {
        const result = await pool.query(
            "UPDATE users SET avatar_url = $1, last_profile_update = NOW() WHERE phone = $2",
            [avatarUrl, phone]
        );

        console.log("   [UserService.uploadAvatar] Rows affected:", result.rowCount);

        return result.rowCount > 0;
    } catch (e) {
        console.error("   [UserService.uploadAvatar] Exception:", e.message);
        throw e;
    }
}
