/**
 * Routes Admin - Gestion Produits
 * GET /admin/products/*
 */
const express = require('express');
const router = express.Router();
const pool = require('../../config/db');
const { BASE_URL } = require('../../config');

// ─── Migration auto au démarrage ───────────────────────────────────────────
(async () => {
    try {
        await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE`);
        await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP`);
        await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS verified_by INT`);
        console.log('✅ Migration products is_verified OK');
    } catch (e) {
        console.warn('Migration products is_verified:', e.message);
    }
})();

/**
 * GET /admin/products
 * Liste tous les produits avec stats globales
 */
router.get('/', async (req, res) => {
    try {
        const { status, is_featured, search, limit = 9999, offset = 0 } = req.query;

        // ── Stats globales ──
        let globalStats = { total: 0, active: 0, banned: 0, featured: 0, good_deals: 0 };
        try {
            const statsResult = await pool.query(`
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE status = 'active') as active,
                    COUNT(*) FILTER (WHERE status = 'banned') as banned,
                    COUNT(*) FILTER (WHERE status = 'hidden') as hidden,
                    COUNT(*) FILTER (WHERE is_featured = TRUE) as featured,
                    COUNT(*) FILTER (WHERE is_good_deal = TRUE) as good_deals
                FROM products
            `);
            globalStats = statsResult.rows[0];
        } catch (e) { console.warn('products stats error:', e.message); }

        // ── Requête principale ──
        let query = `
            SELECT p.*, 
                   u.name as seller_name, 
                   u.phone as seller_phone,
                   u.avatar_url as seller_avatar,
                   u.is_admin as seller_is_admin
            FROM products p
            JOIN users u ON p.seller_id = u.id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (search) {
            query += ` AND (p.name ILIKE $${paramIndex} OR u.phone ILIKE $${paramIndex} OR u.name ILIKE $${paramIndex} OR p.category ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        if (status) {
            query += ` AND p.status = $${paramIndex++}`;
            params.push(status);
        }

        if (is_featured !== undefined) {
            query += ` AND p.is_featured = $${paramIndex++}`;
            params.push(is_featured === 'true');
        }

        query += ` ORDER BY p.created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, params);

        // Formater les images
        const products = result.rows.map(p => {
            let image_url = null;
            if (p.images && p.images.length > 0) {
                const first = p.images[0];
                image_url = first.startsWith('http') ? first : `${BASE_URL}/uploads/${first}`;
            }
            return { ...p, image_url };
        });

        res.json({
            products,
            stats: {
                total: parseInt(globalStats.total),
                active: parseInt(globalStats.active),
                banned: parseInt(globalStats.banned),
                hidden: parseInt(globalStats.hidden || 0),
                featured: parseInt(globalStats.featured),
                good_deals: parseInt(globalStats.good_deals),
            }
        });
    } catch (err) {
        console.error('Erreur GET /admin/products:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/toggle-visibility
 * Masquer / Afficher un produit
 */
router.patch('/:id/toggle-visibility', async (req, res) => {
    try {
        const { id } = req.params;
        // Get current status
        const current = await pool.query('SELECT status FROM products WHERE id = $1', [id]);
        if (current.rows.length === 0) return res.status(404).json({ error: 'Produit introuvable' });

        const newStatus = current.rows[0].status === 'hidden' ? 'active' : 'hidden';
        const result = await pool.query(
            'UPDATE products SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
            [newStatus, id]
        );
        res.json({ message: newStatus === 'hidden' ? 'Produit masqué' : 'Produit visible', product: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH toggle-visibility:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/feature
 */
router.patch('/:id/feature', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_featured } = req.body;
        const result = await pool.query(`UPDATE products SET is_featured = $1, updated_at = NOW() WHERE id = $2 RETURNING *`, [is_featured, id]);
        res.json({ message: is_featured ? 'Produit mis en avant' : 'Produit retiré des featured', product: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/feature:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * DELETE /admin/products/:id
 */
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query(`UPDATE products SET status = 'banned', updated_at = NOW() WHERE id = $1`, [id]);
        res.json({ message: 'Produit banni' });
    } catch (err) {
        console.error('Erreur DELETE /admin/products/:id:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/good-deals
 */
router.get('/good-deals', async (req, res) => {
    try {
        const products = await require('../../repositories/product.repository').findGoodDeals(20);
        res.json(products);
    } catch (err) {
        console.error('Erreur GET /admin/products/good-deals:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/good-deal
 */
router.patch('/:id/good-deal', async (req, res) => {
    try {
        const { id } = req.params;
        const { is_good_deal, promo_price } = req.body;
        const updates = { is_good_deal };
        if (promo_price !== undefined) updates.promo_price = promo_price;
        const product = await require('../../repositories/product.repository').update(id, updates);
        if (!product) return res.status(404).json({ error: 'Produit introuvable' });
        res.json({ message: 'Bon Deal mis à jour', product });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/good-deal:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/verify
 * Toggle étiquette "Produit Vérifié" (is_verified)
 */
router.patch('/:id/verify', async (req, res) => {
    try {
        const { id } = req.params;
        const adminId = req.user.id;
        const current = await pool.query('SELECT is_verified FROM products WHERE id = $1', [id]);
        if (current.rows.length === 0) return res.status(404).json({ error: 'Produit introuvable' });
        const newVal = !current.rows[0].is_verified;
        const result = await pool.query(
            `UPDATE products SET is_verified = $1, verified_at = $2, verified_by = $3, updated_at = NOW() WHERE id = $4 RETURNING id, name, is_verified, verified_at`,
            [newVal, newVal ? new Date() : null, newVal ? adminId : null, id]
        );
        res.json({
            message: newVal ? '✅ Produit vérifié' : 'Vérification retirée',
            product: result.rows[0]
        });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/verify:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/:id/compare
 * Comparateur de prix : stats catégorie + 10 concurrents
 */
router.get('/:id/compare', async (req, res) => {
    try {
        const { id } = req.params;

        // Produit cible
        const prodResult = await pool.query(
            `SELECT p.*, u.name as seller_name, u.phone as seller_phone, u.avatar_url as seller_avatar
             FROM products p JOIN users u ON p.seller_id = u.id WHERE p.id = $1`,
            [id]
        );
        if (prodResult.rows.length === 0) return res.status(404).json({ error: 'Produit introuvable' });
        const product = prodResult.rows[0];

        // Stats de prix pour la même catégorie
        const statsResult = await pool.query(
            `SELECT
               COUNT(*) as total_in_category,
               MIN(price::numeric) as price_min,
               MAX(price::numeric) as price_max,
               ROUND(AVG(price::numeric), 2) as price_avg,
               ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price::numeric), 2) as price_median
             FROM products
             WHERE category = $1 AND status = 'active' AND price::numeric > 0`,
            [product.category]
        );
        const stats = statsResult.rows[0];

        // 10 concurrents les plus proches en prix
        const competitorsResult = await pool.query(
            `SELECT p.id, p.name, p.price, p.images, p.is_verified, u.name as seller_name
             FROM products p JOIN users u ON p.seller_id = u.id
             WHERE p.category = $1 AND p.status = 'active' AND p.id != $2
             ORDER BY ABS(p.price::numeric - $3::numeric) ASC
             LIMIT 10`,
            [product.category, id, product.price]
        );

        res.json({
            product,
            category_stats: {
                total: parseInt(stats?.total_in_category) || 0,
                price_min: parseFloat(stats?.price_min) || 0,
                price_max: parseFloat(stats?.price_max) || 0,
                price_avg: parseFloat(stats?.price_avg) || 0,
                price_median: parseFloat(stats?.price_median) || 0,
            },
            competitors: competitorsResult.rows,
        });
    } catch (err) {
        console.error('Erreur GET /admin/products/:id/compare:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * GET /admin/products/unverified
 * File d'attente : produits non vérifiés avec stats prix catégorie
 */
router.get('/unverified', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const offset = parseInt(req.query.offset) || 0;

        // Migration inline idempotente
        try {
            await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE`);
            await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP`);
            await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS verified_by INT`);
        } catch (me) { /* already exists */ }

        // Produits non vérifiés (actifs)
        const result = await pool.query(
            `SELECT p.id, p.name, p.price, p.images, p.category, p.description, p.status,
                    COALESCE(p.is_verified, FALSE) as is_verified, p.created_at,
                    u.name as seller_name, u.phone as seller_phone, u.avatar_url as seller_avatar
             FROM products p JOIN users u ON p.seller_id = u.id
             WHERE COALESCE(p.is_verified, FALSE) = FALSE AND p.status = 'active'
             ORDER BY p.created_at ASC
             LIMIT $1 OFFSET $2`,
            [limit, offset]
        );

        // Stats par catégorie — prix safe via regexp (ignore non-numériques)
        const products = await Promise.all(result.rows.map(async (p) => {
            try {
                const stats = await pool.query(
                    `SELECT
                        MIN(price::numeric) as price_min,
                        MAX(price::numeric) as price_max,
                        ROUND(AVG(price::numeric), 2) as price_avg,
                        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price::numeric), 2) as price_median,
                        COUNT(*) as total
                     FROM products
                     WHERE category = $1
                       AND status = 'active'
                       AND price ~ '^[0-9]+(\\.?[0-9]*)$'
                       AND price::numeric > 0`,
                    [p.category]
                );
                return { ...p, category_stats: stats.rows[0] || null };
            } catch (se) {
                console.warn(`Stats error for category ${p.category}:`, se.message);
                return { ...p, category_stats: null };
            }
        }));

        // Comptage total
        let total_unverified = 0;
        try {
            const countResult = await pool.query(
                `SELECT COUNT(*) as total FROM products WHERE COALESCE(is_verified, FALSE) = FALSE AND status = 'active'`
            );
            total_unverified = parseInt(countResult.rows[0].total);
        } catch (ce) { /* ignore */ }

        res.json({ products, total_unverified });
    } catch (err) {
        console.error('Erreur GET /admin/products/unverified:', err.message);
        res.status(500).json({ error: err.message });
    }
});

/**
 * PATCH /admin/products/:id/price
 * Modifier le prix d'un produit (admin)
 */
router.patch('/:id/price', async (req, res) => {
    try {
        const { id } = req.params;
        const { price } = req.body;
        if (!price || isNaN(parseFloat(price))) return res.status(400).json({ error: 'Prix invalide' });
        const result = await pool.query(
            `UPDATE products SET price = $1, updated_at = NOW() WHERE id = $2 RETURNING id, name, price`,
            [parseFloat(price), id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Produit introuvable' });
        res.json({ message: 'Prix mis à jour', product: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/price:', err);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * PATCH /admin/products/:id/quick-edit
 * Édition rapide admin : nom, description, prix, shipping_options, brand_certified
 */
router.patch('/:id/quick-edit', async (req, res) => {
    try {
        const { id } = req.params;
        const { name, description, price, shipping_options, brand_certified, brand_display_name } = req.body;

        // Migration inline pour brand
        try {
            await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS brand_certified BOOLEAN DEFAULT FALSE`);
            await pool.query(`ALTER TABLE products ADD COLUMN IF NOT EXISTS brand_display_name VARCHAR(255)`);
        } catch (me) { /* already exists */ }

        // Construire la mise à jour dynamiquement
        const fields = [];
        const values = [];
        let i = 1;

        if (name !== undefined) { fields.push(`name = $${i++}`); values.push(name); }
        if (description !== undefined) { fields.push(`description = $${i++}`); values.push(description); }
        if (price !== undefined) { fields.push(`price = $${i++}`); values.push(parseFloat(price) || 0); }
        if (shipping_options !== undefined) { fields.push(`shipping_options = $${i++}`); values.push(JSON.stringify(shipping_options)); }
        if (brand_certified !== undefined) { fields.push(`brand_certified = $${i++}`); values.push(brand_certified); }
        if (brand_display_name !== undefined) { fields.push(`brand_display_name = $${i++}`); values.push(brand_display_name || null); }

        if (fields.length === 0) return res.status(400).json({ error: 'Rien à mettre à jour' });

        fields.push(`updated_at = NOW()`);
        values.push(id);

        const result = await pool.query(
            `UPDATE products SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
            values
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Produit introuvable' });
        res.json({ message: 'Produit mis à jour', product: result.rows[0] });
    } catch (err) {
        console.error('Erreur PATCH /admin/products/:id/quick-edit:', err.message);
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /admin/products/:id/variants
 * Récupère les variantes d'un produit
 */
router.get('/:id/variants', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(
            `SELECT id, variant_type, variant_value, price_adjustment, stock_quantity, is_active
             FROM product_variants WHERE product_id = $1 ORDER BY variant_type, variant_value`,
            [id]
        );
        res.json({ variants: result.rows });
    } catch (err) {
        console.error('Erreur GET variants:', err.message);
        res.json({ variants: [] }); // Ne pas bloquer si table absente
    }
});

/**
 * POST /admin/products/:id/variants
 * Ajouter ou mettre à jour une variante
 */
router.post('/:id/variants', async (req, res) => {
    try {
        const { id } = req.params;
        const { variant_type, variant_value, price_adjustment = 0, stock_quantity = 0 } = req.body;
        const result = await pool.query(
            `INSERT INTO product_variants (product_id, variant_type, variant_value, price_adjustment, stock_quantity)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (product_id, variant_type, variant_value)
             DO UPDATE SET price_adjustment = $4, stock_quantity = $5, updated_at = NOW()
             RETURNING *`,
            [id, variant_type, variant_value, parseFloat(price_adjustment), parseInt(stock_quantity)]
        );
        res.json({ variant: result.rows[0] });
    } catch (err) {
        console.error('Erreur POST variant:', err.message);
        res.status(500).json({ error: err.message });
    }
});

/**
 * DELETE /admin/products/:pid/variants/:vid
 */
router.delete('/:pid/variants/:vid', async (req, res) => {
    try {
        await pool.query(`DELETE FROM product_variants WHERE id = $1 AND product_id = $2`, [req.params.vid, req.params.pid]);
        res.json({ message: 'Variante supprimée' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
