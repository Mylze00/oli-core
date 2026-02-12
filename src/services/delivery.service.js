const deliveryRepo = require('../repositories/delivery.repository');
const pool = require('../config/db');

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

        const allowed = ['picked_up', 'in_transit', 'delivered', 'cancelled'];
        if (!allowed.includes(status)) throw new Error("Statut invalide");

        const delivery = await deliveryRepo.updateStatus(deliveryId, status, lat, lng);

        // Synchroniser orders.status
        if (delivery && delivery.order_id) {
            const statusMap = {
                'picked_up': 'shipped',
                'in_transit': 'shipped',
                'delivered': 'delivered',
                'cancelled': 'cancelled'
            };
            const orderStatus = statusMap[status];
            if (orderStatus) {
                const tsField = orderStatus === 'shipped' ? 'shipped_at' :
                    orderStatus === 'delivered' ? 'delivered_at' : null;
                const tsClause = tsField ? `, ${tsField} = NOW()` : '';
                await pool.query(
                    `UPDATE orders SET status = $1${tsClause}, updated_at = NOW() WHERE id = $2`,
                    [orderStatus, delivery.order_id]
                );
            }
        }

        // TODO: Notifier le client du changement de statut

        return delivery;
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
    async verifyDelivery(user, deliveryId, code) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");

        // JOIN pour récupérer le delivery_code depuis orders
        const result = await pool.query(`
            SELECT d.*, o.delivery_code as order_delivery_code, o.id as real_order_id
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
        if (!delivery.order_delivery_code || delivery.order_delivery_code.toUpperCase() !== code.toUpperCase()) {
            throw new Error("Code de livraison incorrect");
        }

        // Sync les deux tables → delivered
        await this.updateStatus(user, deliveryId, 'delivered', null, null);
        await pool.query(
            "UPDATE orders SET status = 'delivered', delivered_at = NOW() WHERE id = $1",
            [delivery.real_order_id]
        );

        return { ...delivery, status: 'delivered' };
    }
}

module.exports = new DeliveryService();
