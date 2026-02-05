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
     */
    async updateStatus(user, deliveryId, status, lat, lng) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");

        const allowed = ['picked_up', 'in_transit', 'delivered', 'cancelled'];
        if (!allowed.includes(status)) throw new Error("Statut invalide");

        const delivery = await deliveryRepo.updateStatus(deliveryId, status, lat, lng);

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
     */
    async verifyDelivery(user, deliveryId, code) {
        if (!user.is_deliverer) throw new Error("Accès réservé aux livreurs");

        const delivery = await pool.query('SELECT * FROM delivery_orders WHERE id = $1', [deliveryId]);
        if (delivery.rows.length === 0) throw new Error("Livraison non trouvée");

        const order = delivery.rows[0];
        if (order.deliverer_id !== user.id) throw new Error("Cette livraison ne vous est pas assignée");
        if (order.status !== 'in_transit') throw new Error("La livraison n'est pas en cours");

        // Comparaison du code (insensible à la casse)
        if (!order.delivery_code || order.delivery_code.toUpperCase() !== code.toUpperCase()) {
            throw new Error("Code de livraison incorrect");
        }

        // Si code valide, on marque comme livré
        return await this.updateStatus(user, deliveryId, 'delivered', null, null);
    }
}

module.exports = new DeliveryService();
