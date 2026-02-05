const orderRepository = require('../repositories/order.repository');
const walletService = require('./wallet.service');

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

        // Calcul du total
        const itemsTotal = items.reduce((acc, item) => acc + (item.price * item.quantity), 0);
        const totalAmount = itemsTotal + (parseFloat(deliveryFee) || 0);

        // LOGIQUE PAIEMENT WALLET
        let paymentStatus = 'pending';
        let orderStatus = 'pending';

        if (paymentMethod === 'wallet') {
            try {
                // Tenter le débit du wallet
                // Si solde insuffisant, cette méthode throw une erreur qui bloquera la création de commande
                await walletService.payOrder(userId, totalAmount);

                // Si on arrive ici, le paiement est réussi
                paymentStatus = 'paid';
                orderStatus = 'paid'; // Ou 'processing' selon votre flux
            } catch (err) {
                throw new Error(err.message || "Echec du paiement Wallet");
            }
        }

        // Appel au repo
        // TODO: Vérifier le stock des produits ici avant de créer la commande
        // TODO: Déduire le stock après création (transaction)

        // Note: Il faudra modifier orderRepository.createOrder pour accepter le paymentStatus initial
        // Pour l'instant, on laisse le repo gérer, mais idéalement on passe le statut
        const order = await orderRepository.createOrder(
            userId,
            items,
            deliveryAddress || null,
            paymentMethod || 'wallet',
            parseFloat(deliveryFee) || 0
        );

        // Si payé par wallet, on peut mettre à jour le statut immédiatement si le repo le ne fait pas
        if (paymentStatus === 'paid') {
            await orderRepository.updatePaymentStatus(order.id, 'paid');
            await orderRepository.updateOrderStatus(order.id, 'paid');
            order.status = 'paid';
            order.paymentStatus = 'paid';
        }

        return order;
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
