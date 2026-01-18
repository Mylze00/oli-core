/**
 * Service User - Gestion du profil et activité utilisateur
 */
const pool = require('../config/db');

/**
 * Récupère les produits visités par un utilisateur
 * @param {number} userId - ID de l'utilisateur
 * @param {number} limit - Nombre maximum de produits à retourner (défaut: 20)
 * @returns {Promise<Array>} Liste des produits visités avec leurs infos
 */
async function getVisitedProducts(userId, limit = 20) {
    try {
        const query = `
            SELECT 
                p.id,
                p.name,
                p.price,
                p.images,
                p.description,
                upv.viewed_at,
                u.name as seller_name
            FROM user_product_views upv
            INNER JOIN products p ON upv.product_id = p.id
            LEFT JOIN users u ON p.seller_id = u.id
            WHERE upv.user_id = $1
            ORDER BY upv.viewed_at DESC
            LIMIT $2
        `;

        const result = await pool.query(query, [userId, limit]);

        // Formater les résultats avec imageUrl
        const products = result.rows.map(p => {
            let imgs = [];
            if (Array.isArray(p.images)) {
                imgs = p.images;
            } else if (typeof p.images === 'string') {
                imgs = p.images.replace(/[{}"]/g, '').split(',').filter(Boolean);
            }

            return {
                ...p,
                imageUrl: imgs.length > 0 ? imgs[0] : null,
                images: imgs
            };
        });

        return products;
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
        // On insère toujours une nouvelle entrée pour garder l'historique complet
        const query = `
            INSERT INTO user_product_views (user_id, product_id, viewed_at)
            VALUES ($1, $2, NOW())
        `;

        await pool.query(query, [userId, productId]);
    } catch (error) {
        console.error('Erreur trackProductView:', error);
        // On ne throw pas d'erreur ici pour ne pas bloquer l'affichage du produit
        // Le tracking est une feature secondaire
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
        // 1. Check last update time
        const userCheck = await pool.query('SELECT last_profile_update FROM users WHERE id = $1', [userId]);
        if (userCheck.rows.length > 0) {
            const lastUpdate = userCheck.rows[0].last_profile_update;
            if (lastUpdate) {
                const twoWeeksAgo = new Date();
                twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

                if (new Date(lastUpdate) > twoWeeksAgo) {
                    throw new Error('Vous ne pouvez modifier votre nom qu\'une fois toutes les 2 semaines.');
                }
            }
        }

        const query = `
            UPDATE users 
            SET name = $1, updated_at = NOW(), last_profile_update = NOW()
            WHERE id = $2
            RETURNING id, name, phone, id_oli, avatar_url, wallet, is_seller, is_deliverer, last_profile_update
        `;

        const result = await pool.query(query, [newName.trim(), userId]);

        if (result.rows.length === 0) {
            throw new Error('Utilisateur non trouvé');
        }

        return result.rows[0];
    } catch (error) {
        console.error('Erreur updateUserName:', error);
        throw error;
    }
}

module.exports = {
    getVisitedProducts,
    trackProductView,
    updateUserName
};
