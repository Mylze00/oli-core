const deliveryRepo = require('../repositories/delivery.repository');
const pool = require('../config/db');
const refundService = require('./refund.service');

// Parcours du livreur (suivi par l'acheteur), créé au démarrage s'il n'existe pas
pool.query(`
    CREATE TABLE IF NOT EXISTS delivery_location_points (
        id BIGSERIAL PRIMARY KEY,
        delivery_id INTEGER NOT NULL,
        lat DOUBLE PRECISION NOT NULL,
        lng DOUBLE PRECISION NOT NULL,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_delivery_location_points_delivery
        ON delivery_location_points (delivery_id, recorded_at);
`).catch((e) => console.error('❌ Migration delivery_location_points:', e.message));

class DeliveryService {

    /**
     * Voir les commandes disponibles
     */
    async getAvailableDeliveries(user) {
        if (!user.is_deliverer) {
            throw new Error("Accès réservé aux livreurs");
        }
        return await deliveryRepo.findAvailable();
    }

    /**
     * Accepter une livraison
     */
    async acceptDelivery(user, deliveryId) {
        if (!user.is_deliverer) {
            throw new Error("Accès réservé aux livreurs");
        }

        await refundService.assertDeliveryNotFrozen(deliveryId);

        const delivery = await deliveryRepo.assignDeliverer(deliveryId, user.id);
        if (!delivery) {
            throw new Error("Commande non disponible ou déjà prise");
        }

        // TODO: Notifier le client que la commande est prise en charge

        return delivery;
    }

    /**
     * Mettre à jour le statut (livreur)
     * Synchronise aussi orders.status
     */
    async updateStatus(user, deliveryId, status, lat, lng) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");

        // « livrée » passe uniquement par le code de l'acheteur (verifyDelivery) et
        // « récupérée » par le code de retrait (verify-pickup) : jamais par un simple statut.
        // 'assigned' sert à envoyer la position juste après l'acceptation.
        const allowed = ['assigned', 'in_transit', 'cancelled'];
        if (!allowed.includes(status)) throw new Error("Statut invalide");

        await refundService.assertDeliveryNotFrozen(deliveryId);

        const own = await pool.query('SELECT id, order_id, status, deliverer_id FROM delivery_orders WHERE id = $1', [deliveryId]);
        const current = own.rows[0];
        if (!current) throw new Error("Livraison non trouvée");
        if (Number(current.deliverer_id) !== Number(user.id)) throw new Error("Cette livraison ne vous est pas assignée");
        if (['delivered', 'cancelled'].includes(current.status)) throw new Error("Cette livraison est terminée");

        if (status === 'cancelled') {
            // Le livreur se désiste : la course redevient disponible, la commande continue
            const released = await pool.query(
                `UPDATE delivery_orders SET status = 'pending', deliverer_id = NULL, updated_at = NOW()
                 WHERE id = $1 RETURNING *`,
                [deliveryId]
            );
            return released.rows[0];
        }

        // 'assigned' ne change pas l'étape : seule la position est mise à jour
        const nextStatus = status === 'assigned' ? current.status : status;
        const delivery = await deliveryRepo.updateStatus(deliveryId, nextStatus, lat ?? null, lng ?? null);
        if (lat != null && lng != null) await this._recordPoint(deliveryId, lat, lng);
        return delivery;
    }

    /**
     * Position du livreur pendant une course : mise à jour de la position courante et
     * ajout d'un point au parcours (au plus un point toutes les 10 secondes).
     */
    async recordLocation(user, deliveryId, lat, lng) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");
        const latitude = parseFloat(lat);
        const longitude = parseFloat(lng);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
            throw new Error("Position invalide");
        }
        const { rows } = await pool.query(
            `UPDATE delivery_orders SET current_lat = $1, current_lng = $2, updated_at = NOW()
             WHERE id = $3 AND deliverer_id = $4 AND status IN ('assigned', 'picked_up', 'in_transit')
             RETURNING id, order_id, status`,
            [latitude, longitude, deliveryId, user.id]
        );
        if (!rows[0]) throw new Error("Aucune course en cours pour cette position");
        await this._recordPoint(deliveryId, latitude, longitude);
        return rows[0];
    }

    async _recordPoint(deliveryId, lat, lng) {
        await pool.query(
            `INSERT INTO delivery_location_points (delivery_id, lat, lng)
             SELECT $1, $2, $3
             WHERE NOT EXISTS (
                 SELECT 1 FROM delivery_location_points
                 WHERE delivery_id = $1 AND recorded_at > NOW() - INTERVAL '10 seconds'
             )`,
            [deliveryId, lat, lng]
        ).catch((e) => console.warn('⚠️ Point de parcours non enregistré:', e.message));
    }

    /**
     * Suivi du livreur pour l'acheteur : position, parcours, destination et livreur.
     * Réservé à l'acheteur de la commande, une fois un livreur assigné.
     */
    async getCourierForBuyer(buyerId, orderId) {
        const { rows } = await pool.query(
            `SELECT d.id, d.status, d.current_lat, d.current_lng, d.updated_at,
                    d.pickup_lat, d.pickup_lng, d.pickup_address,
                    d.delivery_lat, d.delivery_lng, d.delivery_address, d.estimated_time,
                    o.user_id, o.status AS order_status,
                    u.name AS deliverer_name, u.phone AS deliverer_phone, u.avatar_url AS deliverer_avatar
             FROM delivery_orders d
             JOIN orders o ON o.id = d.order_id
             LEFT JOIN users u ON u.id = d.deliverer_id
             WHERE d.order_id = $1
             ORDER BY d.id DESC LIMIT 1`,
            [orderId]
        );
        const d = rows[0];
        if (!d || Number(d.user_id) !== Number(buyerId)) {
            const err = new Error('Commande non trouvée');
            err.status = 404;
            throw err;
        }
        if (!d.deliverer_name) return { status: 'waiting_deliverer', order_status: d.order_status };

        const path = await pool.query(
            `SELECT lat, lng, recorded_at FROM delivery_location_points
             WHERE delivery_id = $1 ORDER BY recorded_at ASC LIMIT 500`,
            [d.id]
        );
        const point = (lat, lng) => (lat != null && lng != null ? { lat: parseFloat(lat), lng: parseFloat(lng) } : null);
        return {
            status: d.status,
            order_status: d.order_status,
            estimated_time: d.estimated_time,
            deliverer: { name: d.deliverer_name, phone: d.deliverer_phone, avatar_url: d.deliverer_avatar },
            current: d.current_lat != null ? { ...point(d.current_lat, d.current_lng), updated_at: d.updated_at } : null,
            pickup: { ...point(d.pickup_lat, d.pickup_lng), address: d.pickup_address },
            destination: { ...point(d.delivery_lat, d.delivery_lng), address: d.delivery_address },
            path: path.rows.map((r) => [parseFloat(r.lat), parseFloat(r.lng)]),
        };
    }

    /**
     * Mes livraisons en cours
     */
    async getMyDeliveries(user) {
        if (!user.is_deliverer) return [];
        const deliveries = await deliveryRepo.findByDeliverer(user.id);

        // Enrichir avec indication si le code est requis
        return deliveries.map(d => ({
            ...d,
            qr_required: d.status === 'in_transit'
        }));
    }

    /**
     * Vérifier un code de livraison (QR Code)
     * Utilise orders.delivery_code (source unique de vérité)
     */
    async verifyDelivery(user, deliveryId, code, io = null) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");

        // JOIN pour récupérer le delivery_code depuis orders
        const result = await pool.query(`
            SELECT d.*, o.delivery_code as order_delivery_code, o.id as real_order_id,
                   o.exchange_rate as order_exchange_rate
            FROM delivery_orders d
            JOIN orders o ON d.order_id = o.id
            WHERE d.id = $1
        `, [deliveryId]);
        if (result.rows.length === 0) throw new Error("Livraison non trouvée");

        const delivery = result.rows[0];
        if (delivery.deliverer_id !== user.id) throw new Error("Cette livraison ne vous est pas assignée");
        if (!['in_transit', 'picked_up', 'assigned'].includes(delivery.status)) {
            throw new Error("La livraison n'est pas en cours");
        }

        // Comparer avec orders.delivery_code (source unique)
        if (!delivery.order_delivery_code || delivery.order_delivery_code.toUpperCase() !== String(code || '').trim().toUpperCase()) {
            throw new Error("Code de livraison incorrect");
        }

        // Verrou de ligne : un seul passage à « livrée », donc un seul paiement
        const client = await pool.connect();
        let previousStatus;
        try {
            await client.query('BEGIN');
            const locked = await client.query('SELECT status FROM orders WHERE id = $1 FOR UPDATE', [delivery.real_order_id]);
            previousStatus = locked.rows[0]?.status;
            if (!['shipped', 'ready', 'processing'].includes(previousStatus)) {
                await client.query('ROLLBACK');
                throw new Error('Cette livraison a déjà été validée');
            }
            await client.query(
                "UPDATE orders SET status = 'delivered', delivered_at = NOW(), updated_at = NOW() WHERE id = $1",
                [delivery.real_order_id]
            );
            await client.query(
                `UPDATE delivery_orders SET status = 'delivered', verified_at = NOW(),
                        actual_delivery_time = NOW(), updated_at = NOW()
                 WHERE id = $1`,
                [deliveryId]
            );
            await client.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, 'delivered', $3, 'deliverer')`,
                [delivery.real_order_id, previousStatus, user.id]
            );
            await client.query('COMMIT');
        } catch (err) {
            await client.query('ROLLBACK').catch(() => {});
            throw err;
        } finally {
            client.release();
        }

        // 💰 Vendeur(s) ET livreur payés, comme pour une validation par l'acheteur
        const orderService = require('./order.service');
        await orderService._settleDeliveredOrder(delivery.real_order_id);

        // 🔔 Acheteur et vendeur(s) prévenus
        try {
            const notificationService = require('./notification.service');
            const parties = await pool.query(
                `SELECT o.user_id AS buyer_id, array_remove(array_agg(DISTINCT p.seller_id), NULL) AS seller_ids
                 FROM orders o
                 LEFT JOIN order_items oi ON oi.order_id = o.id
                 LEFT JOIN products p ON p.id::text = oi.product_id
                 WHERE o.id = $1 GROUP BY o.user_id`,
                [delivery.real_order_id]
            );
            const { buyer_id: buyerId, seller_ids: sellerIds = [] } = parties.rows[0] || {};
            if (buyerId) {
                await notificationService.send(buyerId, 'order', 'Commande livrée ✅',
                    `Votre commande #${delivery.real_order_id} a été livrée.`,
                    { order_id: delivery.real_order_id, status: 'delivered' }, io);
            }
            for (const sellerId of sellerIds) {
                await notificationService.send(sellerId, 'order', 'Commande livrée ✅',
                    `La commande #${delivery.real_order_id} a été livrée. Le montant est versé sur votre wallet.`,
                    { order_id: delivery.real_order_id, status: 'delivered' }, io);
            }
        } catch (notifErr) {
            console.error('⚠️ Notification livraison (non-bloquante):', notifErr.message);
        }

        return { ...delivery, status: 'delivered' };
    }
}

module.exports = new DeliveryService();
