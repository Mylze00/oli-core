const pool = require('../config/db');

class ProductRepository {
    async findFeatured(adminPhone, limit) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE u.phone = $1
              AND p.status = 'active'
            ORDER BY p.created_at DESC
            LIMIT $2
        `;
        const result = await pool.query(query, [adminPhone, limit]);
        return result.rows;
    }

    async findTopSellers(limit) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
            ORDER BY COALESCE(p.view_count, 0) DESC, p.created_at DESC
            LIMIT $1
        `;
        const result = await pool.query(query, [limit]);
        return result.rows;
    }

    async findVerifiedShopsProducts(limit) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   s.name as shop_name, 
                   s.is_verified as shop_verified,
                   s.logo_url as shop_logo,
                   p.express_delivery_price
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
              AND (
                  s.is_verified = TRUE 
                  OR u.is_verified = TRUE 
                  OR u.account_type = 'entreprise'
                  OR u.has_certified_shop = TRUE
              )
            ORDER BY p.created_at DESC
            LIMIT $1
        `;
        const result = await pool.query(query, [limit]);
        return result.rows;
    }

    async findGoodDeals(limit) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   s.name as shop_name
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
              AND p.is_good_deal = TRUE
            ORDER BY RANDOM()
            LIMIT $1
        `;
        const result = await pool.query(query, [limit]);
        return result.rows;
    }

    async findAll(filters, limit, offset) {
        let query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status != 'deleted'
        `;

        const params = [];
        let paramIndex = 1;

        if (filters.category) {
            query += ` AND p.category = $${paramIndex++}`;
            params.push(filters.category);
        }
        if (filters.minPrice) {
            query += ` AND p.price >= $${paramIndex++}`;
            params.push(parseFloat(filters.minPrice));
        }
        if (filters.maxPrice) {
            query += ` AND p.price <= $${paramIndex++}`;
            params.push(parseFloat(filters.maxPrice));
        }
        if (filters.location) {
            query += ` AND p.location ILIKE $${paramIndex++}`;
            params.push(`%${filters.location}%`);
        }
        if (filters.search) {
            query += ` AND (p.name ILIKE $${paramIndex} OR p.description ILIKE $${paramIndex})`;
            params.push(`%${filters.search}%`);
            paramIndex++;
        }
        if (filters.shopId) {
            query += ` AND p.shop_id = $${paramIndex++}`;
            params.push(filters.shopId);
        }
        if (filters.seller_id) {
            query += ` AND p.seller_id = $${paramIndex++}`;
            params.push(filters.seller_id);
        }

        // Gestion correcte du statut (active/inactive)
        if (filters.is_active !== undefined) {
            // Si le filtre demande les actifs
            if (filters.is_active === true) {
                query += ` AND p.status = 'active'`;
            }
            // Si le filtre demande les inactifs
            else if (filters.is_active === false) {
                query += ` AND p.status = 'inactive'`;
            }
        } else {
            // Par défaut pour le public (non vendeur), on ne montre que les actifs
            // Mais si seller_id est présent (dashboard vendeur), on montre tout par défaut
            if (!filters.seller_id) {
                query += ` AND p.status = 'active'`;
            }
        }

        query += ` ORDER BY p.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        try {
            const result = await pool.query(query, params);
            return result.rows;
        } catch (err) {
            console.error("❌ SQL Error in findAll:", err.message);
            console.error("Query:", query);
            console.error("Params:", params);
            throw err;
        }
    }

    async findById(id) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.phone as seller_phone,
                   u.rating as seller_rating,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   u.total_sales as seller_total_sales,
                   s.name as shop_name, 
                   s.is_verified as shop_verified,
                   p.express_delivery_price
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.id = $1
        `;
        const result = await pool.query(query, [id]);
        return result.rows[0];
    }

    async incrementViewCount(id) {
        await pool.query("UPDATE products SET view_count = COALESCE(view_count, 0) + 1 WHERE id = $1", [id]);
    }

    async create(product) {
        const {
            seller_id, shop_id, name, description, price, category, images,
            delivery_price, delivery_time, condition, quantity, color, location,
            is_negotiable, b2b_pricing, unit, brand, weight,
            discount_price, discount_start_date, discount_end_date,
            express_delivery_price // New fields
        } = product;

        const query = `
            INSERT INTO products (
                seller_id, shop_id, name, description, price, category, images,
                delivery_price, delivery_time, condition, quantity, color, location,
                is_negotiable, b2b_pricing, unit, brand, weight,
                discount_price, discount_start_date, discount_end_date,
                express_delivery_price,
                status, created_at, updated_at
            )
            VALUES (
                $1, $2, $3, $4, $5, $6, $7, 
                $8, $9, $10, $11, $12, $13, 
                $14, $15, $16, $17, $18,
                $19, $20, $21,
                $22,
                'active', NOW(), NOW()
            )
            RETURNING *
        `;

        const values = [
            seller_id, shop_id, name, description, price, category, images,
            delivery_price, delivery_time, condition, quantity, color, location,
            is_negotiable, JSON.stringify(b2b_pricing || []), unit || 'Pièce', brand || '', weight || '',
            discount_price || null, discount_start_date || null, discount_end_date || null,
            express_delivery_price || null
        ];

        const { rows } = await pool.query(query, values);
        return rows[0];
    }

    async findBySeller(sellerId) {
        const result = await pool.query(
            "SELECT * FROM products WHERE seller_id = $1 ORDER BY created_at DESC",
            [sellerId]
        );
        return result.rows;
    }

    async checkOwnership(productId, sellerId) {
        const result = await pool.query(
            "SELECT id FROM products WHERE id = $1 AND seller_id = $2",
            [productId, sellerId]
        );
        return result.rows.length > 0;
    }

    async update(id, updates) {
        const fields = ['name', 'description', 'price', 'category', 'condition',
            'quantity', 'color', 'location', 'status', 'delivery_price', 'delivery_time',
            'is_good_deal', 'unit', 'brand', 'weight', 'b2b_pricing',
            'discount_price', 'discount_start_date', 'discount_end_date'];
        const setClauses = [];
        const values = [];
        let i = 1;

        for (const field of fields) {
            if (updates[field] !== undefined) {
                setClauses.push(`${field} = $${i++}`);
                values.push(updates[field]);
            }
        }

        if (setClauses.length === 0) return null;

        setClauses.push(`updated_at = NOW()`);
        values.push(id);

        const query = `UPDATE products SET ${setClauses.join(', ')} WHERE id = $${i} RETURNING *`;
        const result = await pool.query(query, values);
        return result.rows[0];
    }

    async softDelete(id, sellerId) {
        const result = await pool.query(
            "UPDATE products SET status = 'deleted', updated_at = NOW() WHERE id = $1 AND seller_id = $2 RETURNING id",
            [id, sellerId]
        );
        return result.rows;
    }

    /**
     * Récupère les produits en promotion active pour une boutique
     * @param {string} shopId - ID de la boutique
     * @param {number} limit - Nombre maximum de résultats
     */
    async findActivePromotions(shopId, limit = 12) {
        const query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.avatar_url as seller_avatar, 
                   u.id_oli as seller_oli_id,
                   u.is_verified as seller_is_verified,
                   u.account_type as seller_account_type,
                   u.has_certified_shop as seller_has_certified_shop,
                   s.name as shop_name, 
                   s.is_verified as shop_verified
            FROM products p 
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.shop_id = $1
              AND p.status = 'active'
              AND p.discount_price IS NOT NULL
              AND p.discount_start_date IS NOT NULL
              AND p.discount_end_date IS NOT NULL
              AND p.discount_start_date <= NOW()
              AND p.discount_end_date >= NOW()
            ORDER BY p.discount_end_date ASC
            LIMIT $2
        `;
        const result = await pool.query(query, [shopId, limit]);
        return result.rows;
    }

    /**
     * Recherche produits par mots-clés (pour recherche visuelle)
     * @param {Array<string>} keywords - Liste de mots-clés à rechercher
     * @param {number} limit - Nombre maximum de résultats
     */
    async searchByKeywords(keywords, limit = 50) {
        if (!keywords || keywords.length === 0) {
            return [];
        }

        // Construire la requête dynamiquement
        const conditions = [];
        const values = [];
        let paramIndex = 1;

        keywords.forEach(keyword => {
            const pattern = `%${keyword.toLowerCase()}%`;
            conditions.push(`(
                LOWER(p.name) LIKE $${paramIndex}
                OR LOWER(p.description) LIKE $${paramIndex}
                OR LOWER(p.category) LIKE $${paramIndex}
                OR LOWER(p.color) LIKE $${paramIndex}
                OR LOWER(p.brand) LIKE $${paramIndex}
            )`);
            values.push(pattern);
            paramIndex++;
        });

        const query = `
            SELECT DISTINCT p.*,
                   u.name as seller_name,
                   u.avatar_url as seller_avatar,
                   u.id_oli as seller_oli_id,
                   s.name as shop_name,
                   s.is_verified as shop_verified
            FROM products p
            JOIN users u ON p.seller_id = u.id
            LEFT JOIN shops s ON p.shop_id = s.id
            WHERE p.status = 'active'
              AND (${conditions.join(' OR ')})
            ORDER BY p.created_at DESC
            LIMIT $${paramIndex}
        `;

        values.push(limit);

        const result = await pool.query(query, values);
        return result.rows;
    }
}

module.exports = new ProductRepository();
