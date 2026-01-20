const orderRepository = require('../repositories/order.repository');

class OrderService {
    async createOrder(userId, data) {
        const { items, deliveryAddress, paymentMethod, deliveryFee } = data;

        // Validation de base
        if (!items || !Array.isArray(items) || items.length === 0) {
            throw new Error("Items requis");
        }

        // Validation des items
        for (const item of items) {
            if (!item.productId || !item.productName || !item.price || !item.quantity) {
                throw new Error("Chaque item doit avoir productId, productName, price et quantity");
            }
        }

        // Appel au repo
        // TODO: Vérifier le stock des produits ici avant de créer la commande
        // TODO: Déduire le stock après création (transaction)

        return await orderRepository.createOrder(
            userId,
            items,
            deliveryAddress || null,
            paymentMethod || 'wallet',
            parseFloat(deliveryFee) || 0
        );
    }

    async getUserOrders(userId) {
        return await orderRepository.getOrdersByUser(userId);
    }

    async getOrderById(userId, orderId) {
        const order = await orderRepository.getOrderById(orderId, userId);
        if (!order) {
            throw new Error("Commande non trouvée");
        }
        return order;
    }

    async updateStatus(orderId, status) {
        const validStatuses = ['pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'];
        if (!validStatuses.includes(status)) {
            throw new Error("Statut invalide");
        }

        const order = await orderRepository.updateOrderStatus(orderId, status);
        if (!order) {
            throw new Error("Commande non trouvée");
        }
        return order;
    }

    async cancelOrder(userId, orderId) {
        const order = await orderRepository.cancelOrder(orderId, userId);
        if (!order) {
            throw new Error("Impossible d'annuler cette commande (déjà expédiée ou annulée)");
        }
        return order;
    }

    // DEV ONLY
    async simulatePayment(orderId, paymentMethod) {
        const order = await orderRepository.updatePaymentStatus(orderId, 'completed');
        if (!order) {
            throw new Error("Commande non trouvée");
        }
        return order;
    }
}

module.exports = new OrderService();
