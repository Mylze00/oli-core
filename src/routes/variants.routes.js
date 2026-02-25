/**
 * Routes Variantes Produits
 * CRUD pour les variantes (taille, couleur, etc.)
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const db = require('../config/db');

/**
 * Middleware pour vérifier que l'utilisateur est vendeur
 */
const requireSeller = (req, res, next) => {
    if (!req.user.is_seller) {
        return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
    }
    next();
};

/**
 * Middleware pour vérifier que le produit appartient au vendeur
 */
const requireProductOwner = async (req, res, next) => {
    const productId = req.params.productId || req.body.product_id;

    if (!productId) {
        return res.status(400).json({ error: 'ID produit requis' });
    }

    const result = await db.query(
        'SELECT id FROM products WHERE id = $1 AND seller_id = $2',
        [productId, req.user.id]
    );

    if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Produit non trouvé ou non autorisé' });
    }

    next();
};

/**
 * GET /variants/:productId
 * Liste des variantes d'un produit
 */
router.get('/:productId', requireAuth, requireSeller, requireProductOwner, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT * FROM product_variants
            WHERE product_id = $1
            ORDER BY variant_type, variant_value
        `, [req.params.productId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /variants/:productId:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

/**
 * POST /variants/:productId
 * Ajouter une variante à un produit
 */
router.post('/:productId', requireAuth, requireSeller, requireProductOwner, async (req, res) => {
    try {
        const { variant_type, variant_value, sku, price_adjustment, stock_quantity } = req.body;

        if (!variant_type || !variant_value) {
            return res.status(400).json({ error: 'Type et valeur de variante requis' });
        }

        // Vérifier si la variante existe déjà
        const existing = await db.query(`
            SELECT id FROM product_variants 
            WHERE product_id = $1 AND variant_type = $2 AND variant_value = $3
        `, [req.params.productId, variant_type, variant_value]);

        if (existing.rows.length > 0) {
            return res.status(409).json({ error: 'Cette variante existe déjà' });
        }

        const result = await db.query(`
            INSERT INTO product_variants (
                product_id, variant_type, variant_value, 
                sku, price_adjustment, stock_quantity
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `, [
            req.params.productId,
            variant_type,
            variant_value,
            sku || null,
            price_adjustment || 0,
            stock_quantity || 0
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error POST /variants/:productId:', error);
        res.status(500).json({ error: 'Erreur lors de la création de la variante' });
    }
});

/**
 * POST /variants/:productId/bulk
 * Ajouter plusieurs variantes d'un coup
 */
router.post('/:productId/bulk', requireAuth, requireSeller, requireProductOwner, async (req, res) => {
    const client = await db.connect();

    try {
        const { variants } = req.body;

        if (!Array.isArray(variants) || variants.length === 0) {
            return res.status(400).json({ error: 'Liste de variantes requise' });
        }

        await client.query('BEGIN');

        const created = [];
        const errors = [];

        for (const variant of variants) {
            const { variant_type, variant_value, sku, price_adjustment, stock_quantity } = variant;

            if (!variant_type || !variant_value) {
                errors.push({ variant, error: 'Type et valeur requis' });
                continue;
            }

            try {
                const result = await client.query(`
                    INSERT INTO product_variants (
                        product_id, variant_type, variant_value, 
                        sku, price_adjustment, stock_quantity
                    )
                    VALUES ($1, $2, $3, $4, $5, $6)
                    ON CONFLICT (product_id, variant_type, variant_value) 
                    DO UPDATE SET 
                        price_adjustment = EXCLUDED.price_adjustment,
                        stock_quantity = EXCLUDED.stock_quantity,
                        updated_at = NOW()
                    RETURNING *
                `, [
                    req.params.productId,
                    variant_type,
                    variant_value,
                    sku || null,
                    price_adjustment || 0,
                    stock_quantity || 0
                ]);

                created.push(result.rows[0]);
            } catch (err) {
                errors.push({ variant, error: err.message });
            }
        }

        await client.query('COMMIT');

        res.status(201).json({
            success: true,
            created: created.length,
            errors: errors.length,
            variants: created,
            error_details: errors
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error POST /variants/:productId/bulk:', error);
        res.status(500).json({ error: 'Erreur lors de la création des variantes' });
    } finally {
        client.release();
    }
});

/**
 * PUT /variants/:variantId
 * Modifier une variante
 */
router.put('/:variantId', requireAuth, requireSeller, async (req, res) => {
    try {
        const { variant_type, variant_value, sku, price_adjustment, stock_quantity, is_active } = req.body;

        // Vérifier que la variante appartient au vendeur
        const checkResult = await db.query(`
            SELECT v.id FROM product_variants v
            JOIN products p ON p.id = v.product_id
            WHERE v.id = $1 AND p.seller_id = $2
        `, [req.params.variantId, req.user.id]);

        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Variante non trouvée' });
        }

        const result = await db.query(`
            UPDATE product_variants SET
                variant_type = COALESCE($1, variant_type),
                variant_value = COALESCE($2, variant_value),
                sku = COALESCE($3, sku),
                price_adjustment = COALESCE($4, price_adjustment),
                stock_quantity = COALESCE($5, stock_quantity),
                is_active = COALESCE($6, is_active),
                updated_at = NOW()
            WHERE id = $7
            RETURNING *
        `, [variant_type, variant_value, sku, price_adjustment, stock_quantity, is_active, req.params.variantId]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error PUT /variants/:variantId:', error);
        res.status(500).json({ error: 'Erreur lors de la modification' });
    }
});

/**
 * DELETE /variants/:variantId
 * Supprimer une variante
 */
router.delete('/:variantId', requireAuth, requireSeller, async (req, res) => {
    try {
        // Vérifier que la variante appartient au vendeur
        const checkResult = await db.query(`
            SELECT v.id FROM product_variants v
            JOIN products p ON p.id = v.product_id
            WHERE v.id = $1 AND p.seller_id = $2
        `, [req.params.variantId, req.user.id]);

        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Variante non trouvée' });
        }

        await db.query('DELETE FROM product_variants WHERE id = $1', [req.params.variantId]);

        res.json({ success: true, message: 'Variante supprimée' });
    } catch (error) {
        console.error('Error DELETE /variants/:variantId:', error);
        res.status(500).json({ error: 'Erreur lors de la suppression' });
    }
});

/**
 * PUT /variants/:productId/stock
 * Mise à jour du stock en masse pour les variantes
 */
router.put('/:productId/stock', requireAuth, requireSeller, requireProductOwner, async (req, res) => {
    const client = await db.connect();

    try {
        const { updates } = req.body;

        if (!Array.isArray(updates)) {
            return res.status(400).json({ error: 'Liste de mises à jour requise' });
        }

        await client.query('BEGIN');

        for (const update of updates) {
            const { variant_id, stock_quantity } = update;

            if (variant_id && typeof stock_quantity === 'number') {
                await client.query(`
                    UPDATE product_variants 
                    SET stock_quantity = $1, updated_at = NOW()
                    WHERE id = $2 AND product_id = $3
                `, [stock_quantity, variant_id, req.params.productId]);
            }
        }

        await client.query('COMMIT');

        res.json({ success: true, updated: updates.length });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error PUT /variants/:productId/stock:', error);
        res.status(500).json({ error: 'Erreur lors de la mise à jour du stock' });
    } finally {
        client.release();
    }
});

/**
 * GET /variants/types/suggestions
 * Suggestions de types de variantes courantes
 */
router.get('/types/suggestions', requireAuth, requireSeller, (req, res) => {
    res.json({
        types: [
            { value: 'size', label: 'Taille', examples: ['XS', 'S', 'M', 'L', 'XL', 'XXL'] },
            { value: 'color', label: 'Couleur', examples: ['Noir', 'Blanc', 'Rouge', 'Bleu', 'Vert'] },
            { value: 'material', label: 'Matériau', examples: ['Coton', 'Polyester', 'Cuir', 'Métal'] },
            { value: 'capacity', label: 'Capacité', examples: ['16GB', '32GB', '64GB', '128GB'] },
            { value: 'style', label: 'Style', examples: ['Classique', 'Moderne', 'Vintage', 'Sport'] },
            { value: 'packaging', label: 'Conditionnement', examples: ['Unitaire', 'Lot de 3', 'Lot de 6', 'Carton'] }
        ]
    });
});

/**
 * GET /variants/public/:productId
 * Liste des variantes actives d'un produit (endpoint public pour les acheteurs)
 */
router.get('/public/:productId', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT id, product_id, variant_type, variant_value, 
                   price_adjustment, stock_quantity
            FROM product_variants
            WHERE product_id = $1 AND is_active = true
            ORDER BY variant_type, variant_value
        `, [req.params.productId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /variants/public/:productId:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
