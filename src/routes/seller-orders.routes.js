/**
 * Routes Seller Orders - Gestion des commandes vendeur
 * Workflow complet avec transitions d'état et notifications
 * 
 * @created 2026-02-04
 */

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middlewares/auth.middleware');
const db = require('../config/db');
const notificationRepo = require('../repositories/notification.repository');

/**
 * Middleware pour vérifier que l'utilisateur est vendeur
 * Vérifie en DB (pas seulement le JWT qui peut être stale)
 */
const requireSeller = async (req, res, next) => {
    try {
        // Vérifier is_seller en DB OU si l'utilisateur a des produits publiés
        const result = await db.query(
            `SELECT u.is_seller, (SELECT COUNT(*) FROM products WHERE seller_id = u.id) as product_count
             FROM users u WHERE u.id = $1`,
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(403).json({ error: 'Utilisateur introuvable' });
        }

        const user = result.rows[0];
        if (!user.is_seller && parseInt(user.product_count) === 0) {
            return res.status(403).json({ error: 'Accès réservé aux vendeurs' });
        }

        // Auto-promouvoir en vendeur si l'utilisateur a des produits mais n'est pas marqué vendeur
        if (!user.is_seller && parseInt(user.product_count) > 0) {
            await db.query('UPDATE users SET is_seller = true WHERE id = $1', [req.user.id]);
            console.log(`✅ User #${req.user.id} auto-promu vendeur (${user.product_count} produits)`);
        }

        next();
    } catch (err) {
        console.error('Erreur requireSeller:', err.message);
        return res.status(500).json({ error: 'Erreur vérification vendeur' });
    }
};

/**
 * Transitions de statut autorisées pour les vendeurs
 * Le statut 'shipped' est géré par le livreur (verify-pickup)
 * Le statut 'delivered' est géré par l'acheteur (verify-delivery) ou le livreur
 */
const SELLER_TRANSITIONS = {
    'paid': ['processing'],           // Commande payée → En préparation
    'processing': ['ready'],          // En préparation → Prête (livreur notifié)
};

const STATUS_LABELS = {
    'pending': 'En attente',
    'paid': 'Payée',
    'processing': 'En préparation',
    'ready': 'Prête pour expédition',
    'shipped': 'Expédiée',
    'delivered': 'Livrée',
    'cancelled': 'Annulée'
};

/**
 * GET /seller/orders - Liste des commandes du vendeur
 */
router.get('/', requireAuth, requireSeller, async (req, res) => {
    try {
        const { status, limit = 50, offset = 0 } = req.query;

        let query = `
            SELECT DISTINCT o.id, o.user_id, o.status, o.payment_status,
                   o.total_amount, o.delivery_address, o.delivery_fee,
                   o.delivery_method_id, o.pickup_code,
                   o.tracking_number, o.carrier, o.estimated_delivery,
                   o.shipped_at, o.delivered_at, o.created_at, o.updated_at,
                   u.name as buyer_name, u.phone as buyer_phone,
                   json_agg(json_build_object(
                       'id', oi.id,
                       'product_id', oi.product_id,
                       'product_name', oi.product_name,
                       'product_image_url', oi.product_image_url,
                       'price', oi.product_price,
                       'quantity', oi.quantity
                   )) as items
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            JOIN users u ON u.id = o.user_id
            WHERE p.seller_id = $1
        `;

        const params = [req.user.id];

        if (status) {
            params.push(status);
            query += ` AND o.status = $${params.length}`;
        }

        query += ` GROUP BY o.id, u.name, u.phone ORDER BY o.created_at DESC`;
        query += ` LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(parseInt(limit), parseInt(offset));

        const result = await db.query(query, params);

        // Compter par statut
        const countQuery = `
            SELECT o.status, COUNT(DISTINCT o.id) as count
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE p.seller_id = $1
            GROUP BY o.status
        `;
        const countResult = await db.query(countQuery, [req.user.id]);

        const statusCounts = {};
        countResult.rows.forEach(row => {
            statusCounts[row.status] = parseInt(row.count);
        });

        // Convertir les champs DECIMAL (string) en nombres pour Flutter
        const sanitizedOrders = result.rows.map(order => ({
            ...order,
            total_amount: order.total_amount != null ? parseFloat(order.total_amount) : 0,
            delivery_fee: order.delivery_fee != null ? parseFloat(order.delivery_fee) : 0,
        }));

        res.json({
            orders: sanitizedOrders,
            status_counts: statusCounts,
            total: sanitizedOrders.length
        });
    } catch (error) {
        console.error('Error GET /seller/orders:', error);
        res.status(500).json({ error: 'Erreur récupération commandes' });
    }
});

/**
 * GET /seller/orders/:id - Détails d'une commande
 */
router.get('/:id', requireAuth, requireSeller, async (req, res) => {
    try {
        // Vérifier que la commande contient des produits du vendeur
        const orderQuery = `
            SELECT o.*, u.name as buyer_name, u.phone as buyer_phone, u.email as buyer_email,
                   json_agg(json_build_object(
                       'id', oi.id,
                       'product_id', oi.product_id,
                       'product_name', oi.product_name,
                       'product_image_url', oi.product_image_url,
                       'price', oi.product_price,
                       'quantity', oi.quantity,
                       'seller_name', oi.seller_name
                   )) as items
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            JOIN users u ON u.id = o.user_id
            WHERE o.id = $1 AND p.seller_id = $2
            GROUP BY o.id, u.name, u.phone, u.email
        `;

        const orderResult = await db.query(orderQuery, [req.params.id, req.user.id]);

        if (orderResult.rows.length === 0) {
            return res.status(404).json({ error: 'Commande non trouvée' });
        }

        // Récupérer l'historique des statuts
        const historyResult = await db.query(`
            SELECT h.*, u.name as changed_by_name
            FROM order_status_history h
            LEFT JOIN users u ON u.id = h.changed_by
            WHERE h.order_id = $1
            ORDER BY h.created_at DESC
        `, [req.params.id]);

        res.json({
            ...orderResult.rows[0],
            status_history: historyResult.rows,
            allowed_transitions: SELLER_TRANSITIONS[orderResult.rows[0].status] || []
        });
    } catch (error) {
        console.error('Error GET /seller/orders/:id:', error);
        res.status(500).json({ error: 'Erreur récupération commande' });
    }
});

/**
 * PATCH /seller/orders/:id/status - Changer le statut d'une commande
 * Délègue à order.service.js pour markProcessing et markReady 
 * afin d'envoyer les notifications aux livreurs et acheteurs
 */
router.patch('/:id/status', requireAuth, requireSeller, async (req, res) => {
    const { status, tracking_number, carrier, estimated_delivery, notes, delivery_method_id } = req.body;
    const io = req.app.get('io');

    try {
        // Vérifier que la commande appartient au vendeur
        const checkQuery = `
            SELECT DISTINCT o.id, o.status, o.user_id
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id::text = oi.product_id
            WHERE o.id = $1 AND p.seller_id = $2
        `;
        const checkResult = await db.query(checkQuery, [req.params.id, req.user.id]);

        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Commande non trouvée' });
        }

        const currentStatus = checkResult.rows[0].status;

        // Vérifier la transition
        const allowedTransitions = SELLER_TRANSITIONS[currentStatus] || [];
        if (!allowedTransitions.includes(status)) {
            return res.status(400).json({
                error: `Transition non autorisée: ${currentStatus} → ${status}`,
                allowed: allowedTransitions
            });
        }

        // Utiliser les méthodes du service pour les transitions standards
        // Elles gèrent notifications acheteur + livreur + Socket.IO
        const orderService = require('../services/order.service');
        let updatedOrder;

        if (status === 'processing') {
            updatedOrder = await orderService.markProcessing(req.params.id, req.user.id, io);
            console.log(`✅ Commande #${req.params.id}: paid → processing (via seller #${req.user.id})`);
        } else if (status === 'ready') {
            updatedOrder = await orderService.markReady(req.params.id, req.user.id, io);
            console.log(`✅ Commande #${req.params.id}: processing → ready (via seller #${req.user.id}), livreurs notifiés`);
        } else {
            // Fallback pour les autres transitions (shipped via tracking etc.)
            const client = await db.connect();
            try {
                await client.query('BEGIN');

                let updateQuery = `UPDATE orders SET status = $1, updated_at = NOW()`;
                const updateParams = [status];

                if (status === 'shipped') {
                    updateQuery += `, shipped_at = NOW()`;
                    if (tracking_number) {
                        updateParams.push(tracking_number);
                        updateQuery += `, tracking_number = $${updateParams.length}`;
                    }
                    if (carrier) {
                        updateParams.push(carrier);
                        updateQuery += `, carrier = $${updateParams.length}`;
                    }
                    if (estimated_delivery) {
                        updateParams.push(estimated_delivery);
                        updateQuery += `, estimated_delivery = $${updateParams.length}`;
                    }
                } else if (status === 'delivered') {
                    updateQuery += `, delivered_at = NOW()`;
                }

                updateParams.push(req.params.id);
                updateQuery += ` WHERE id = $${updateParams.length} RETURNING *`;

                const updateResult = await client.query(updateQuery, updateParams);

                await client.query(`
                    INSERT INTO order_status_history 
                    (order_id, previous_status, new_status, changed_by, changed_by_role, notes)
                    VALUES ($1, $2, $3, $4, 'seller', $5)
                `, [req.params.id, currentStatus, status, req.user.id, notes || null]);

                // Notification acheteur
                const buyerId = checkResult.rows[0].user_id;
                const notifMessage = status === 'shipped'
                    ? `Votre commande #${req.params.id} a été expédiée${tracking_number ? ` - Suivi: ${tracking_number}` : ''}`
                    : `Statut de votre commande #${req.params.id}: ${STATUS_LABELS[status]}`;

                try {
                    await notificationRepo.create(buyerId, 'order_status', 'Commande mise à jour', notifMessage, { order_id: parseInt(req.params.id), status });
                    if (io) {
                        io.to(`user_${buyerId}`).emit('order_status_updated', { order_id: parseInt(req.params.id), status, message: notifMessage });
                    }
                } catch (notifError) {
                    console.error('⚠️ Erreur notification acheteur (non-bloquante):', notifError.message);
                }

                await client.query('COMMIT');
                updatedOrder = updateResult.rows[0];
            } catch (err) {
                await client.query('ROLLBACK');
                throw err;
            } finally {
                client.release();
            }
        }

        res.json({
            success: true,
            order: updatedOrder,
            message: `Statut mis à jour: ${STATUS_LABELS[status]}`
        });
    } catch (error) {
        console.error('Error PATCH /seller/orders/:id/status:', error);
        res.status(500).json({ error: error.message || 'Erreur mise à jour statut' });
    }
});

/**
 * GET /seller/orders/stats/summary - Statistiques commandes
 */
router.get('/stats/summary', requireAuth, requireSeller, async (req, res) => {
    try {
        const query = `
            WITH seller_orders AS (
                SELECT DISTINCT o.id, o.status, o.total_amount, o.created_at
                FROM orders o
                JOIN order_items oi ON oi.order_id = o.id
                JOIN products p ON p.id::text = oi.product_id
                WHERE p.seller_id = $1
            )
            SELECT 
                COUNT(*) FILTER (WHERE status = 'paid') as to_process,
                COUNT(*) FILTER (WHERE status = 'processing') as processing,
                COUNT(*) FILTER (WHERE status = 'shipped') as shipped,
                COUNT(*) FILTER (WHERE status = 'delivered') as delivered,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as new_today,
                COALESCE(SUM(total_amount) FILTER (WHERE status = 'delivered'), 0) as delivered_revenue
            FROM seller_orders
        `;

        const result = await db.query(query, [req.user.id]);
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error GET /seller/orders/stats/summary:', error);
        res.status(500).json({ error: 'Erreur statistiques' });
    }
});

/**
 * GET /seller/notifications - Notifications vendeur
 */
router.get('/notifications', requireAuth, requireSeller, async (req, res) => {
    try {
        const { unread_only = false, limit = 20 } = req.query;

        let query = `
            SELECT * FROM seller_notifications
            WHERE seller_id = $1
        `;

        if (unread_only === 'true') {
            query += ` AND is_read = false`;
        }

        query += ` ORDER BY created_at DESC LIMIT $2`;

        const result = await db.query(query, [req.user.id, parseInt(limit)]);

        // Compter non lues
        const unreadResult = await db.query(
            'SELECT COUNT(*) FROM seller_notifications WHERE seller_id = $1 AND is_read = false',
            [req.user.id]
        );

        res.json({
            notifications: result.rows,
            unread_count: parseInt(unreadResult.rows[0].count)
        });
    } catch (error) {
        console.error('Error GET /seller/notifications:', error);
        res.status(500).json({ error: 'Erreur notifications' });
    }
});

/**
 * PATCH /seller/notifications/:id/read - Marquer comme lu
 */
router.patch('/notifications/:id/read', requireAuth, requireSeller, async (req, res) => {
    try {
        await db.query(
            'UPDATE seller_notifications SET is_read = true WHERE id = $1 AND seller_id = $2',
            [req.params.id, req.user.id]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Error PATCH /seller/notifications/:id/read:', error);
        res.status(500).json({ error: 'Erreur mise à jour' });
    }
});

/**
 * POST /seller/notifications/read-all - Tout marquer comme lu
 */
router.post('/notifications/read-all', requireAuth, requireSeller, async (req, res) => {
    try {
        await db.query(
            'UPDATE seller_notifications SET is_read = true WHERE seller_id = $1',
            [req.user.id]
        );
        res.json({ success: true });
    } catch (error) {
        console.error('Error POST /seller/notifications/read-all:', error);
        res.status(500).json({ error: 'Erreur mise à jour' });
    }
});

module.exports = router;
