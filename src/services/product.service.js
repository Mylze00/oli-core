const productRepository = require('../repositories/product.repository');
const { BASE_URL } = require('../config');
const pool = require('../config/db'); // For updating user sales count (should be in UserRepo technically, but keeping consistent for now)

class ProductService {
    _formatImages(images) {
        let imgs = [];
        if (Array.isArray(images)) {
            imgs = images;
        } else if (typeof images === 'string') {
            imgs = images.replace(/[{}"]/g, '').split(',').filter(Boolean);
        }

        return imgs.map(img => {
            if (!img) return null;
            if (img.startsWith('http')) return img;
            return `${BASE_URL}/uploads/${img}`;
        }).filter(url => url !== null);
    }

    _formatProduct(p) {
        const imageUrls = this._formatImages(p.images);
        
        return {
            id: p.id,
            name: p.name,
            description: p.description,
            price: parseFloat(p.price).toFixed(2),
            category: p.category,
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
            isFeatured: p.isFeatured // For featured query
        };
    }

    async getFeaturedProducts(limit = 20) {
        const ADMIN_PHONE = '+243827088682';
        const products = await productRepository.findFeatured(ADMIN_PHONE, limit);
        
        return products.map(p => {
            const formatted = this._formatProduct(p);
            formatted.isFeatured = true;
            return formatted;
        });
    }

    async getTopSellers(limit = 10) {
        const products = await productRepository.findTopSellers(limit);
        return products.map(p => this._formatProduct(p));
    }

    async getVerifiedShopsProducts(limit = 10) {
        const products = await productRepository.findVerifiedShopsProducts(limit);
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
        if (!data.name || !data.price) {
            throw new Error('Nom et prix requis');
        }

        const images = files ? files.map(f => f.path || f.filename) : [];
        
        const productData = {
            seller_id: userId,
            shop_id: (data.shop_id && data.shop_id !== "" && data.shop_id !== "null") ? parseInt(data.shop_id) : null,
            name: data.name,
            description: data.description,
            price: parseFloat(data.price) || 0,
            category: data.category,
            images,
            delivery_price: parseFloat(data.delivery_price || 0),
            delivery_time: data.delivery_time,
            condition: data.condition,
            quantity: parseInt(data.quantity || 1),
            color: data.color,
            location: data.location,
            is_negotiable: data.is_negotiable === 'true' || data.is_negotiable === true
        };

        const createdProduct = await productRepository.create(productData);

        // Update User Sales Count (Side effect)
        // TODO: Move this to UserRepository.updateSalesCount
        await pool.query("UPDATE users SET total_sales = COALESCE(total_sales, 0) + 1 WHERE id = $1", [userId]);

        return createdProduct.id;
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
}

module.exports = new ProductService();
