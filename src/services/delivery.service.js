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
        return await deliveryRepo.findByDeliverer(user.id);
    }
}

module.exports = new DeliveryService();
