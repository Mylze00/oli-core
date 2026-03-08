const db = require('../config/db');
const pool = db; // Alias for consistency if used as pool
const shopRepository = require('../repositories/shop.repository');
const userRepo = require('../repositories/user.repository');
const productRepository = require('../repositories/product.repository');
const imageService = require('./image.service');
const { categorizeByName } = require('./product_categorizer.service');

class ProductService {
    // ... (méthodes existantes: _formatImages, _formatProduct, getFeaturedProducts, getTopSellers, getVerifiedShopsProducts)

    // ...

    _formatImages(images) {
        let imgs = [];
        if (Array.isArray(images)) {
            imgs = images;
        } else if (typeof images === 'string') {
            imgs = images.replace(/[{}"]/g, '').split(',').filter(Boolean);
        }

        return imageService.formatImageArray(imgs);
    }

    _formatProduct(p) {
        const imageUrls = this._formatImages(p.images);

        return {
            id: p.id,
            name: p.name,
            description: p.description,
            price: parseFloat(p.price).toFixed(2),
            category: p.category,
            subcategory: p.subcategory || null,
            condition: p.condition,
            quantity: p.quantity,
            color: p.color,
            location: p.location,
            isNegotiable: p.is_negotiable,
            deliveryPrice: parseFloat(p.delivery_price || 0).toFixed(2),
            deliveryTime: p.delivery_time,
            sellerId: p.seller_id,
            sellerName: p.seller_name,
            sellerAvatar: p.seller_avatar,
            sellerOliId: p.seller_oli_id,
            shopId: p.shop_id,
            shopName: p.shop_name,
            shopVerified: p.shop_verified,
            shopLogo: p.shop_logo, // Only present for verified shops query
            imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
            images: imageUrls,
            status: p.status,
            createdAt: p.created_at,
            viewCount: p.view_count || 0,
            sellerSalesCount: p.seller_total_sales || 0,
            expressDeliveryPrice: parseFloat(p.express_delivery_price) || null,
            shippingOptions: p.shipping_options || [],
            brandCertified: p.brand_certified || false,
            brandDisplayName: p.brand_display_name || null,
            isFeatured: p.isFeatured // For featured query
        };
    }

    async getFeaturedProducts(limit = 100, offset = 0) {
        const ADMIN_PHONE = '+243827088682';
        const products = await productRepository.findFeatured(ADMIN_PHONE, limit, offset);

        return products.map(p => {
            const formatted = this._formatProduct(p);
            formatted.isFeatured = true;
            return formatted;
        });
    }

    async getBrandedProducts(limit = 50) {
        const ADMIN_PHONE = '+243827088682';
        const products = await productRepository.findBranded(ADMIN_PHONE, limit);
        return products.map(p => this._formatProduct(p));
    }

    async getTopSellers(limit = 50) {
        const products = await productRepository.findTopSellers(limit);
        return products.map(p => this._formatProduct(p));
    }

    async getVerifiedShopsProducts(limit = 10) {
        const ADMIN_PHONE = '+243827088682';
        const products = await productRepository.findVerifiedShopsProducts(ADMIN_PHONE, limit);
        return products.map(p => {
            const formatted = this._formatProduct(p);
            formatted.shopVerified = true; // Explicitly true from query
            return formatted;
        });
    }

    async getAllProducts(filters, limit = 50, offset = 0) {
        const products = await productRepository.findAll(filters, limit, offset);
        return products.map(p => this._formatProduct(p));
    }

    async getProductById(id) {
        const product = await productRepository.findById(id);
        if (!product) return null;

        await productRepository.incrementViewCount(id);

        // Custom formatting for detail view (consistent with previous route)
        const imageUrls = this._formatImages(product.images);

        return {
            ...product,
            images: imageUrls,
            price: parseFloat(product.price).toFixed(2),
            deliveryPrice: parseFloat(product.delivery_price || 0).toFixed(2),
        };
    }

    async createProduct(userId, data, files) {
        // Validation
        const price = data.price || data.basePrice; // Support legacy/frontend alias
        if (!data.name || !price) {
            throw new Error('Nom et prix requis');
        }

        // Images uploadées (fichiers binaires)
        const uploadedImages = files ? files.map(f => f.path || f.filename) : [];

        // Images URL pré-remplies (depuis un brouillon importé, format existing_images)
        let prefillImages = [];
        if (data.existing_images) {
            try {
                prefillImages = JSON.parse(data.existing_images);
                if (!Array.isArray(prefillImages)) prefillImages = [];
            } catch (e) {
                console.warn('Erreur parsing existing_images:', e.message);
            }
        }

        // Fusionner : images uploadées + URLs pré-remplies (sans doublons)
        const images = [...new Set([...uploadedImages, ...prefillImages])];

        // 1. Déterminer le shop_id
        let shopId = (data.shop_id && !isNaN(data.shop_id)) ? parseInt(data.shop_id) : null;

        // Si aucun shop_id n'est fourni, on cherche si le vendeur a une boutique
        if (!shopId) {
            try {
                const userShops = await shopRepository.findByOwnerId(userId);
                if (userShops && userShops.length > 0) {
                    // On prend la première boutique trouvée (souvent l'unique)
                    shopId = userShops[0].id;
                    console.log(`🛒 Produit lié automatiquement à la boutique ID: ${shopId} pour le vendeur ${userId}`);
                }
            } catch (err) {
                console.warn(`⚠️ Impossible de récupérer les boutiques pour l'auto-liaison: ${err.message}`);
            }
        }

        // ── Auto-catégorisation ──────────────────────────────────────────────
        // Si la catégorie n'est pas fournie, est 'other' ou manquante → analyser le nom
        let resolvedCategory = data.category;
        let resolvedSubcategory = data.subcategory || null;

        const needsClassification = !resolvedCategory
            || resolvedCategory === 'other'
            || resolvedCategory === 'autres'
            || resolvedCategory === 'Autres';

        if (needsClassification || !resolvedSubcategory) {
            try {
                const classified = categorizeByName(data.name, data.description || '');
                if (needsClassification && classified.confidence >= 30) {
                    resolvedCategory = classified.category;
                }
                if (!resolvedSubcategory) {
                    resolvedSubcategory = classified.subcategory;
                }
                console.log(`🏷️ Auto-classification: "${data.name}" → ${classified.category}/${classified.subcategory} (${classified.confidence}%)`);
            } catch (classErr) {
                console.warn('⚠️ Auto-classification échouée:', classErr.message);
            }
        }
        // ────────────────────────────────────────────────────────────────────

        const productData = {
            seller_id: userId,
            shop_id: (shopId && !isNaN(shopId)) ? shopId : null,
            name: data.name,
            description: data.description,
            price: parseFloat(price) || 0, // Use aliased price
            category: resolvedCategory || 'other',
            subcategory: resolvedSubcategory,
            images,
            delivery_price: parseFloat(data.delivery_price || 0),
            delivery_time: data.delivery_time,
            condition: data.condition,
            quantity: parseInt(data.quantity || 1) || 1,
            color: data.color,
            location: data.location,
            is_negotiable: data.is_negotiable === 'true' || data.is_negotiable === true,
            b2b_pricing: (() => {
                try {
                    return data.b2b_pricing ? JSON.parse(data.b2b_pricing) : [];
                } catch (e) {
                    console.warn("Erreur parsing B2B pricing:", e.message);
                    return [];
                }
            })(),
            shipping_options: (() => {
                try {
                    return data.shipping_options ? JSON.parse(data.shipping_options) : [];
                } catch (e) {
                    console.warn("Erreur parsing Shipping Options:", e.message);
                    return [];
                }
            })(),
            unit: data.unit || 'Pièce',
            brand: data.brand || '',
            weight: data.weight || '',
            discount_price: (data.discount_price && !isNaN(data.discount_price)) ? parseFloat(data.discount_price) : null,
            discount_start_date: data.discount_start_date || null,
            discount_end_date: data.discount_end_date || null
        };

        const createdProduct = await productRepository.create(productData);
        const productId = createdProduct.id;

        // ── Insert product variants (colors & sizes) ──
        try {
            const colorsArr = data.colors ? JSON.parse(data.colors) : [];
            const sizesArr = data.sizes ? JSON.parse(data.sizes) : [];

            for (const color of colorsArr) {
                if (color && color.trim()) {
                    await pool.query(
                        `INSERT INTO product_variants (product_id, variant_type, variant_value, stock_quantity, is_active)
                         VALUES ($1, 'color', $2, $3, true)
                         ON CONFLICT (product_id, variant_type, variant_value) DO NOTHING`,
                        [productId, color.trim(), parseInt(data.quantity || 1) || 1]
                    );
                }
            }

            for (const size of sizesArr) {
                if (size && size.trim()) {
                    await pool.query(
                        `INSERT INTO product_variants (product_id, variant_type, variant_value, stock_quantity, is_active)
                         VALUES ($1, 'size', $2, $3, true)
                         ON CONFLICT (product_id, variant_type, variant_value) DO NOTHING`,
                        [productId, size.trim(), parseInt(data.quantity || 1) || 1]
                    );
                }
            }

            if (colorsArr.length > 0 || sizesArr.length > 0) {
                console.log(`🎨 Variantes créées pour produit ${productId}: ${colorsArr.length} couleur(s), ${sizesArr.length} taille(s)`);
            }
        } catch (variantErr) {
            console.warn(`⚠️ Erreur insertion variantes pour produit ${productId}:`, variantErr.message);
        }

        // Update User Sales Count
        await pool.query("UPDATE users SET total_sales = COALESCE(total_sales, 0) + 1 WHERE id = $1", [userId]);

        return productId;
    }

    async getUserProducts(userId) {
        const products = await productRepository.findBySeller(userId);
        return products.map(p => ({
            ...p,
            images: this._formatImages(p.images)
        }));
    }

    async updateProduct(userId, productId, updates) {
        const isOwner = await productRepository.checkOwnership(productId, userId);
        if (!isOwner) {
            throw new Error('Non autorisé');
        }

        // ── Auto-reclassification si le nom change ou si demandé ──────────
        if (updates.name || updates.force_reclassify) {
            try {
                const classified = categorizeByName(
                    updates.name || '',
                    updates.description || ''
                );
                if (classified.confidence >= 30) {
                    // Ne forcer la catégorie que si non fournie ou 'other'
                    if (!updates.category || updates.category === 'other') {
                        updates.category = classified.category;
                    }
                    // Toujours mettre à jour la sous-catégorie
                    updates.subcategory = classified.subcategory;
                    console.log(`🏷️ Reclassification update: "${updates.name}" → ${classified.category}/${classified.subcategory} (${classified.confidence}%)`);
                }
            } catch (classErr) {
                console.warn('⚠️ Reclassification update échouée:', classErr.message);
            }
        }
        // ────────────────────────────────────────────────────────────────────

        const updated = await productRepository.update(productId, updates);
        if (!updated) {
            throw new Error('Aucune modification fournie');
        }
        return updated;
    }

    async deleteProduct(userId, productId) {
        const success = await productRepository.softDelete(productId, userId);
        if (!success) {
            throw new Error('Non autorisé ou produit inexistant');
        }
        return true;
    }

    async bulkUpdateShopPrices(userId, shopId, divisor) {
        // 1. Vérifier que l'utilisateur est propriétaire de la boutique
        const shop = await shopRepository.findById(shopId);

        if (!shop) {
            throw new Error('Boutique non trouvée');
        }

        // Vérification stricte : le userId doit correspondre au owner_id de la boutique
        // Note: shop.owner_id peut être un int ou string selon le driver DB, on normalise en string
        if (shop.owner_id.toString() !== userId.toString()) {
            throw new Error('Non autorisé : Vous n\'êtes pas le propriétaire de cette boutique');
        }

        // 2. Appliquer la mise à jour
        const updatedProducts = await productRepository.bulkUpdatePriceByShopId(shopId, divisor);

        return {
            count: updatedProducts.length,
            sample: updatedProducts.slice(0, 5) // Renvoie un échantillon pour vérification
        };
    }
}

module.exports = new ProductService();
