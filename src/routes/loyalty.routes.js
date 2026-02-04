/**
 * Routes Programme Fidélité
 * Gestion des points, transactions, et configuration
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

// ================================
// ROUTES VENDEUR
// ================================

/**
 * GET /settings - Configuration fidélité du vendeur
 */
router.get('/settings', requireAuth, requireSeller, async (req, res) => {
    try {
        let result = await db.query(
            'SELECT * FROM loyalty_settings WHERE seller_id = $1',
            [req.user.id]
        );

        if (result.rows.length === 0) {
            // Créer une config par défaut
            result = await db.query(`
                INSERT INTO loyalty_settings (seller_id) VALUES ($1)
                RETURNING *
            `, [req.user.id]);
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /loyalty/settings:', error);
        res.status(500).json({ error: 'Erreur récupération paramètres' });
    }
});

/**
 * PUT /settings - Modifier configuration fidélité
 */
router.put('/settings', requireAuth, requireSeller, async (req, res) => {
    try {
        const {
            is_enabled, points_per_dollar, points_value,
            min_points_redeem, welcome_bonus, expiry_months,
            tier_thresholds, tier_multipliers
        } = req.body;

        const result = await db.query(`
            INSERT INTO loyalty_settings (seller_id, is_enabled, points_per_dollar, points_value,
                min_points_redeem, welcome_bonus, expiry_months, tier_thresholds, tier_multipliers)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (seller_id) DO UPDATE SET
                is_enabled = COALESCE($2, loyalty_settings.is_enabled),
                points_per_dollar = COALESCE($3, loyalty_settings.points_per_dollar),
                points_value = COALESCE($4, loyalty_settings.points_value),
                min_points_redeem = COALESCE($5, loyalty_settings.min_points_redeem),
                welcome_bonus = COALESCE($6, loyalty_settings.welcome_bonus),
                expiry_months = $7,
                tier_thresholds = COALESCE($8, loyalty_settings.tier_thresholds),
                tier_multipliers = COALESCE($9, loyalty_settings.tier_multipliers),
                updated_at = NOW()
            RETURNING *
        `, [
            req.user.id, is_enabled, points_per_dollar, points_value,
            min_points_redeem, welcome_bonus, expiry_months,
            tier_thresholds ? JSON.stringify(tier_thresholds) : null,
            tier_multipliers ? JSON.stringify(tier_multipliers) : null
        ]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error PUT /loyalty/settings:', error);
        res.status(500).json({ error: 'Erreur mise à jour paramètres' });
    }
});

/**
 * GET /customers - Liste des clients fidélité du vendeur
 */
router.get('/customers', requireAuth, requireSeller, async (req, res) => {
    try {
        const { tier, sort = 'points_desc', limit = 50 } = req.query;

        let orderBy = 'lp.points_balance DESC';
        if (sort === 'earned_desc') orderBy = 'lp.total_points_earned DESC';
        if (sort === 'recent') orderBy = 'lp.updated_at DESC';

        let tierFilter = '';
        const params = [req.user.id];
        if (tier) {
            tierFilter = 'AND lp.tier = $2';
            params.push(tier);
        }

        const result = await db.query(`
            SELECT lp.*, u.name as user_name, u.phone as user_phone, u.avatar_url
            FROM loyalty_points lp
            JOIN users u ON u.id = lp.user_id
            WHERE lp.seller_id = $1 ${tierFilter}
            ORDER BY ${orderBy}
            LIMIT ${parseInt(limit)}
        `, params);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /loyalty/customers:', error);
        res.status(500).json({ error: 'Erreur récupération clients' });
    }
});

/**
 * GET /stats - Statistiques programme fidélité
 */
router.get('/stats', requireAuth, requireSeller, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT 
                (SELECT COUNT(*) FROM loyalty_points WHERE seller_id = $1) as total_members,
                (SELECT SUM(points_balance) FROM loyalty_points WHERE seller_id = $1) as total_points_outstanding,
                (SELECT SUM(total_points_earned) FROM loyalty_points WHERE seller_id = $1) as total_points_earned,
                (SELECT SUM(total_points_spent) FROM loyalty_points WHERE seller_id = $1) as total_points_redeemed,
                (SELECT COUNT(*) FROM loyalty_points WHERE seller_id = $1 AND tier = 'bronze') as bronze_members,
                (SELECT COUNT(*) FROM loyalty_points WHERE seller_id = $1 AND tier = 'silver') as silver_members,
                (SELECT COUNT(*) FROM loyalty_points WHERE seller_id = $1 AND tier = 'gold') as gold_members,
                (SELECT COUNT(*) FROM loyalty_points WHERE seller_id = $1 AND tier = 'platinum') as platinum_members
        `, [req.user.id]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /loyalty/stats:', error);
        res.status(500).json({ error: 'Erreur statistiques' });
    }
});

/**
 * POST /award - Attribuer des points bonus à un client
 */
router.post('/award', requireAuth, requireSeller, async (req, res) => {
    try {
        const { user_id, points, description } = req.body;

        if (!user_id || !points) {
            return res.status(400).json({ error: 'Client et points requis' });
        }

        // Récupérer ou créer le compte fidélité
        let loyaltyResult = await db.query(
            'SELECT id FROM loyalty_points WHERE seller_id = $1 AND user_id = $2',
            [req.user.id, user_id]
        );

        let loyaltyId;
        if (loyaltyResult.rows.length === 0) {
            const insertResult = await db.query(`
                INSERT INTO loyalty_points (seller_id, user_id, points_balance, total_points_earned)
                VALUES ($1, $2, $3, $3)
                RETURNING id
            `, [req.user.id, user_id, points]);
            loyaltyId = insertResult.rows[0].id;
        } else {
            loyaltyId = loyaltyResult.rows[0].id;
            await db.query(`
                UPDATE loyalty_points 
                SET points_balance = points_balance + $1,
                    total_points_earned = total_points_earned + $1,
                    updated_at = NOW()
                WHERE id = $2
            `, [points, loyaltyId]);
        }

        // Créer la transaction
        await db.query(`
            INSERT INTO loyalty_transactions (loyalty_id, type, points, description)
            VALUES ($1, 'bonus', $2, $3)
        `, [loyaltyId, points, description || 'Points bonus']);

        res.json({ success: true, points_awarded: points });
    } catch (error) {
        console.error('Error POST /loyalty/award:', error);
        res.status(500).json({ error: 'Erreur attribution points' });
    }
});

// ================================
// ROUTES CLIENT
// ================================

/**
 * GET /my-points - Points du client chez tous les vendeurs
 */
router.get('/my-points', requireAuth, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT lp.*, u.name as seller_name, s.shop_name,
                   ls.points_value, ls.min_points_redeem
            FROM loyalty_points lp
            JOIN users u ON u.id = lp.seller_id
            LEFT JOIN shops s ON s.user_id = lp.seller_id
            LEFT JOIN loyalty_settings ls ON ls.seller_id = lp.seller_id
            WHERE lp.user_id = $1
            ORDER BY lp.points_balance DESC
        `, [req.user.id]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error GET /loyalty/my-points:', error);
        res.status(500).json({ error: 'Erreur récupération points' });
    }
});

/**
 * GET /my-points/:sellerId - Points chez un vendeur spécifique
 */
router.get('/my-points/:sellerId', requireAuth, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT lp.*, ls.points_value, ls.min_points_redeem
            FROM loyalty_points lp
            LEFT JOIN loyalty_settings ls ON ls.seller_id = lp.seller_id
            WHERE lp.user_id = $1 AND lp.seller_id = $2
        `, [req.user.id, req.params.sellerId]);

        if (result.rows.length === 0) {
            return res.json({ points_balance: 0, tier: 'bronze' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /loyalty/my-points/:sellerId:', error);
        res.status(500).json({ error: 'Erreur récupération points' });
    }
});

/**
 * POST /redeem - Utiliser des points
 */
router.post('/redeem', requireAuth, async (req, res) => {
    try {
        const { seller_id, points, order_id } = req.body;

        if (!seller_id || !points) {
            return res.status(400).json({ error: 'Vendeur et points requis' });
        }

        // Vérifier le solde
        const loyaltyResult = await db.query(`
            SELECT lp.*, ls.min_points_redeem, ls.points_value
            FROM loyalty_points lp
            LEFT JOIN loyalty_settings ls ON ls.seller_id = lp.seller_id
            WHERE lp.user_id = $1 AND lp.seller_id = $2
        `, [req.user.id, seller_id]);

        if (loyaltyResult.rows.length === 0) {
            return res.status(400).json({ error: 'Pas de compte fidélité' });
        }

        const loyalty = loyaltyResult.rows[0];

        if (points > loyalty.points_balance) {
            return res.status(400).json({ error: 'Solde insuffisant' });
        }

        if (points < (loyalty.min_points_redeem || 0)) {
            return res.status(400).json({
                error: `Minimum ${loyalty.min_points_redeem} points requis`
            });
        }

        // Déduire les points
        await db.query(`
            UPDATE loyalty_points 
            SET points_balance = points_balance - $1,
                total_points_spent = total_points_spent + $1,
                updated_at = NOW()
            WHERE id = $2
        `, [points, loyalty.id]);

        // Créer la transaction
        await db.query(`
            INSERT INTO loyalty_transactions (loyalty_id, type, points, order_id, description)
            VALUES ($1, 'spend', $2, $3, 'Utilisation sur commande')
        `, [loyalty.id, -points, order_id]);

        const discount_value = points * parseFloat(loyalty.points_value || 0.01);

        res.json({
            success: true,
            points_used: points,
            discount_value,
            new_balance: loyalty.points_balance - points
        });
    } catch (error) {
        console.error('Error POST /loyalty/redeem:', error);
        res.status(500).json({ error: 'Erreur utilisation points' });
    }
});

/**
 * POST /earn - Gagner des points (appelé après une commande)
 * @internal - Appelé par le système
 */
router.post('/earn', requireAuth, async (req, res) => {
    try {
        const { seller_id, order_id, order_amount } = req.body;

        // Récupérer les paramètres fidélité
        const settingsResult = await db.query(
            'SELECT * FROM loyalty_settings WHERE seller_id = $1',
            [seller_id]
        );

        if (settingsResult.rows.length === 0 || !settingsResult.rows[0].is_enabled) {
            return res.json({ success: false, message: 'Programme fidélité non actif' });
        }

        const settings = settingsResult.rows[0];

        // Récupérer ou créer compte fidélité
        let loyaltyResult = await db.query(
            'SELECT * FROM loyalty_points WHERE seller_id = $1 AND user_id = $2',
            [seller_id, req.user.id]
        );

        let loyaltyId;
        let currentTier = 'bronze';
        let multiplier = settings.tier_multipliers?.bronze || 1;

        if (loyaltyResult.rows.length === 0) {
            // Nouveau client: bonus de bienvenue
            const welcomePoints = settings.welcome_bonus || 0;
            const insertResult = await db.query(`
                INSERT INTO loyalty_points (seller_id, user_id, points_balance, total_points_earned)
                VALUES ($1, $2, $3, $3)
                RETURNING id
            `, [seller_id, req.user.id, welcomePoints]);
            loyaltyId = insertResult.rows[0].id;

            if (welcomePoints > 0) {
                await db.query(`
                    INSERT INTO loyalty_transactions (loyalty_id, type, points, description)
                    VALUES ($1, 'bonus', $2, 'Bonus de bienvenue')
                `, [loyaltyId, welcomePoints]);
            }
        } else {
            loyaltyId = loyaltyResult.rows[0].id;
            currentTier = loyaltyResult.rows[0].tier;
            multiplier = settings.tier_multipliers?.[currentTier] || 1;
        }

        // Calculer les points gagnés
        const basePoints = Math.floor(order_amount * parseFloat(settings.points_per_dollar || 1));
        const earnedPoints = Math.floor(basePoints * multiplier);

        // Ajouter les points
        await db.query(`
            UPDATE loyalty_points 
            SET points_balance = points_balance + $1,
                total_points_earned = total_points_earned + $1,
                updated_at = NOW()
            WHERE id = $2
        `, [earnedPoints, loyaltyId]);

        // Transaction
        await db.query(`
            INSERT INTO loyalty_transactions (loyalty_id, type, points, order_id, description)
            VALUES ($1, 'earn', $2, $3, $4)
        `, [loyaltyId, earnedPoints, order_id, `Achat de $${order_amount}`]);

        // Vérifier upgrade de tier
        const newTotalResult = await db.query(
            'SELECT total_points_earned FROM loyalty_points WHERE id = $1',
            [loyaltyId]
        );
        const totalEarned = newTotalResult.rows[0].total_points_earned;
        const thresholds = settings.tier_thresholds || { silver: 500, gold: 2000, platinum: 5000 };

        let newTier = 'bronze';
        if (totalEarned >= thresholds.platinum) newTier = 'platinum';
        else if (totalEarned >= thresholds.gold) newTier = 'gold';
        else if (totalEarned >= thresholds.silver) newTier = 'silver';

        if (newTier !== currentTier) {
            await db.query('UPDATE loyalty_points SET tier = $1 WHERE id = $2', [newTier, loyaltyId]);
        }

        res.json({
            success: true,
            points_earned: earnedPoints,
            tier: newTier,
            tier_upgraded: newTier !== currentTier
        });
    } catch (error) {
        console.error('Error POST /loyalty/earn:', error);
        res.status(500).json({ error: 'Erreur attribution points' });
    }
});

module.exports = router;
