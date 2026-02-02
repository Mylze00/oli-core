/**
 * Service centralisé pour la gestion des URLs d'images
 * Garantit la cohérence entre toutes les plateformes (App, Admin, Seller Center)
 */

const CLOUD_NAME = 'dbfpnxjmm';
const CLOUDINARY_BASE = `https://res.cloudinary.com/${CLOUD_NAME}/image/upload`;
const { BASE_URL } = require('../config');

class ImageService {
    /**
     * Formate une URL d'image unique
     * @param {string|null} path - Le chemin de l'image (peut être Cloudinary, local, ou URL complète)
     * @returns {string|null} - L'URL complète formatée
     */
    formatImageUrl(path) {
        if (!path) return null;

        // Si c'est déjà une URL complète (http/https), on retourne tel quel
        if (path.startsWith('http://') || path.startsWith('https://')) {
            return path;
        }

        // Nettoyer le path (enlever le slash initial si présent)
        const cleanPath = path.startsWith('/') ? path.slice(1) : path;

        // Si le path est vide après nettoyage, retourner null
        if (!cleanPath || cleanPath.trim() === '') {
            return null;
        }

        // Si c'est un fichier local (uploads/)
        if (cleanPath.startsWith('uploads/')) {
            return `${BASE_URL}/${cleanPath}`;
        }

        // Valider le path Cloudinary - doit contenir un dossier et un fichier
        // Ignorer les paths qui ressemblent à des UUIDs seuls ou des paths invalides
        const hasValidFormat = cleanPath.includes('/') || cleanPath.includes('.');
        if (!hasValidFormat) {
            console.warn(`⚠️ Image path invalide ignoré: ${cleanPath}`);
            return null;
        }

        // Sinon, c'est un path Cloudinary
        return `${CLOUDINARY_BASE}/${cleanPath}`;
    }


    /**
     * Formate un tableau d'URLs d'images
     * @param {Array|string} images - Tableau ou chaîne représentant les images
     * @returns {Array<string>} - Tableau d'URLs formatées
     */
    formatImageArray(images) {
        let imageArray = [];

        if (Array.isArray(images)) {
            imageArray = images;
        } else if (typeof images === 'string') {
            // Parse PostgreSQL array format: {img1,img2}
            imageArray = images.replace(/[{}\"]/g, '').split(',').filter(Boolean);
        }

        return imageArray.map(img => this.formatImageUrl(img)).filter(url => url !== null);
    }

    /**
     * Formate un objet utilisateur avec ses images
     * @param {Object} user - Objet utilisateur brut
     * @returns {Object} - Utilisateur avec URLs formatées
     */
    formatUserImages(user) {
        if (!user) return null;

        return {
            ...user,
            avatar_url: this.formatImageUrl(user.avatar_url)
        };
    }

    /**
     * Formate un objet boutique avec ses images
     * @param {Object} shop - Objet boutique brut
     * @returns {Object} - Boutique avec URLs formatées
     */
    formatShopImages(shop) {
        if (!shop) return null;

        return {
            ...shop,
            logo_url: this.formatImageUrl(shop.logo_url),
            banner_url: this.formatImageUrl(shop.banner_url),
            owner_avatar: this.formatImageUrl(shop.owner_avatar)
        };
    }

    /**
     * Formate un objet produit avec ses images
     * @param {Object} product - Objet produit brut
     * @returns {Object} - Produit avec URLs formatées
     */
    formatProductImages(product) {
        if (!product) return null;

        const imageUrls = this.formatImageArray(product.images);

        return {
            ...product,
            images: imageUrls,
            imageUrl: imageUrls.length > 0 ? imageUrls[0] : null
        };
    }
}

module.exports = new ImageService();
