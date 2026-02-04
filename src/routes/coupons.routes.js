/**
 * Routes Coupons Vendeur
 * CRUD codes promo et validation
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const db = require('../config/db');

/**
 * Middleware vendeur
 */
const requireSeller = (req, res, next) => {
    if (!req.user.is_seller) {
        return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
    }
    next();
};

/**
 * GET / - Liste des coupons du vendeur
 */
router.get('/', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT c.*, 
                   (SELECT COUNT(*) FROM coupon_usages cu WHERE cu.coupon_id = c.id) as total_uses
            FROM coupons c
            WHERE c.seller_id = $1
            ORDER BY c.created_at DESC
        `, [req.user.id]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /coupons:', error);
        res.status(500).json({ error: 'Erreur récupération coupons' });
    }
});

/**
 * POST / - Créer un coupon
 */
router.post('/', requireAuth, requireSeller, async (req, res) => {
    try {
        const {
            code, type = 'percentage', value,
            min_order_amount = 0, max_discount_amount,
            max_uses, max_uses_per_user = 1,
            valid_from, valid_until,
            applies_to = 'all', product_ids, category_ids
        } = req.body;

        if (!code || !value) {
            return res.status(400).json({ error: 'Code et valeur requis' });
        }

        const result = await db.query(`
            INSERT INTO coupons (
                seller_id, code, type, value, min_order_amount, max_discount_amount,
                max_uses, max_uses_per_user, valid_from, valid_until,
                applies_to, product_ids, category_ids
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *
        `, [
            req.user.id, code.toUpperCase(), type, value,
            min_order_amount, max_discount_amount,
            max_uses, max_uses_per_user,
            valid_from || new Date(), valid_until,
            applies_to, product_ids, category_ids
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Ce code existe déjà' });
        }
        console.error('Error POST /coupons:', error);
        res.status(500).json({ error: 'Erreur création coupon' });
    }
});

/**
 * PUT /:id - Modifier un coupon
 */
router.put('/:id', requireAuth, requireSeller, async (req, res) => {
    try {
        const { id } = req.params;
        const {
            code, type, value, min_order_amount, max_discount_amount,
            max_uses, max_uses_per_user, valid_from, valid_until,
            applies_to, product_ids, category_ids, is_active
        } = req.body;

        const result = await db.query(`
            UPDATE coupons SET
                code = COALESCE($1, code),
                type = COALESCE($2, type),
                value = COALESCE($3, value),
                min_order_amount = COALESCE($4, min_order_amount),
                max_discount_amount = $5,
                max_uses = $6,
                max_uses_per_user = COALESCE($7, max_uses_per_user),
                valid_from = COALESCE($8, valid_from),
                valid_until = $9,
                applies_to = COALESCE($10, applies_to),
                product_ids = $11,
                category_ids = $12,
                is_active = COALESCE($13, is_active),
                updated_at = NOW()
            WHERE id = $14 AND seller_id = $15
            RETURNING *
        `, [
            code?.toUpperCase(), type, value, min_order_amount, max_discount_amount,
            max_uses, max_uses_per_user, valid_from, valid_until,
            applies_to, product_ids, category_ids, is_active,
            id, req.user.id
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Coupon non trouvé' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error PUT /coupons/:id:', error);
        res.status(500).json({ error: 'Erreur modification coupon' });
    }
});

/**
 * DELETE /:id - Supprimer un coupon
 */
router.delete('/:id', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(
            'DELETE FROM coupons WHERE id = $1 AND seller_id = $2 RETURNING id',
            [req.params.id, req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Coupon non trouvé' });
        }

        res.json({ success: true });
    } catch (error) {
        console.error('Error DELETE /coupons/:id:', error);
        res.status(500).json({ error: 'Erreur suppression coupon' });
    }
});

/**
 * POST /validate - Valider un code promo (côté client/checkout)
 */
router.post('/validate', requireAuth, async (req, res) => {
    try {
        const { code, seller_id, order_amount, product_ids } = req.body;

        if (!code || !seller_id) {
            return res.status(400).json({ error: 'Code et vendeur requis' });
        }

        // Récupérer le coupon
        const couponResult = await db.query(`
            SELECT * FROM coupons
            WHERE code = $1 AND seller_id = $2 AND is_active = true
              AND (valid_from IS NULL OR valid_from <= NOW())
              AND (valid_until IS NULL OR valid_until >= NOW())
        `, [code.toUpperCase(), seller_id]);

        if (couponResult.rows.length === 0) {
            return res.status(400).json({ error: 'Code promo invalide ou expiré' });
        }

        const coupon = couponResult.rows[0];

        // Vérifier limites d'utilisation
        if (coupon.max_uses && coupon.current_uses >= coupon.max_uses) {
            return res.status(400).json({ error: 'Ce code a atteint sa limite d\'utilisation' });
        }

        // Vérifier utilisation par utilisateur
        const userUsageResult = await db.query(
            'SELECT COUNT(*) FROM coupon_usages WHERE coupon_id = $1 AND user_id = $2',
            [coupon.id, req.user.id]
        );
        if (parseInt(userUsageResult.rows[0].count) >= coupon.max_uses_per_user) {
            return res.status(400).json({ error: 'Vous avez déjà utilisé ce code' });
        }

        // Vérifier montant minimum
        if (order_amount && order_amount < parseFloat(coupon.min_order_amount)) {
            return res.status(400).json({
                error: `Montant minimum requis: $${coupon.min_order_amount}`,
                min_amount: coupon.min_order_amount
            });
        }

        // Calculer la remise
        let discount = 0;
        if (coupon.type === 'percentage') {
            discount = (order_amount || 0) * (parseFloat(coupon.value) / 100);
            if (coupon.max_discount_amount) {
                discount = Math.min(discount, parseFloat(coupon.max_discount_amount));
            }
        } else if (coupon.type === 'fixed_amount') {
            discount = parseFloat(coupon.value);
        }

        res.json({
            valid: true,
            coupon_id: coupon.id,
            type: coupon.type,
            value: coupon.value,
            discount_amount: discount,
            message: coupon.type === 'free_shipping' ? 'Livraison gratuite appliquée' : `Remise de $${discount.toFixed(2)}`
        });
    } catch (error) {
        console.error('Error POST /coupons/validate:', error);
        res.status(500).json({ error: 'Erreur validation coupon' });
    }
});

/**
 * POST /apply - Appliquer un coupon à une commande
 */
router.post('/apply', requireAuth, async (req, res) => {
    try {
        const { coupon_id, order_id, discount_applied } = req.body;

        // Enregistrer l'utilisation
        await db.query(`
            INSERT INTO coupon_usages (coupon_id, user_id, order_id, discount_applied)
            VALUES ($1, $2, $3, $4)
        `, [coupon_id, req.user.id, order_id, discount_applied]);

        // Incrémenter le compteur
        await db.query(
            'UPDATE coupons SET current_uses = current_uses + 1 WHERE id = $1',
            [coupon_id]
        );

        res.json({ success: true });
    } catch (error) {
        console.error('Error POST /coupons/apply:', error);
        res.status(500).json({ error: 'Erreur application coupon' });
    }
});

/**
 * GET /stats - Statistiques coupons vendeur
 */
router.get('/stats', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT 
                (SELECT COUNT(*) FROM coupons WHERE seller_id = $1) as total_coupons,
                (SELECT COUNT(*) FROM coupons WHERE seller_id = $1 AND is_active = true) as active_coupons,
                (SELECT COALESCE(SUM(discount_applied), 0) FROM coupon_usages cu 
                 JOIN coupons c ON c.id = cu.coupon_id WHERE c.seller_id = $1) as total_discount_given,
                (SELECT COUNT(*) FROM coupon_usages cu 
                 JOIN coupons c ON c.id = cu.coupon_id WHERE c.seller_id = $1) as total_uses
        `, [req.user.id]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /coupons/stats:', error);
        res.status(500).json({ error: 'Erreur statistiques' });
    }
});

module.exports = router;
