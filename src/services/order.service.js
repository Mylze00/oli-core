const orderRepository = require('../repositories/order.repository');
const walletService = require('./wallet.service');
const notificationService = require('./notification.service');
const pool = require('../config/db');

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

    async getDeliveryOrders() {
        return await orderRepository.getDeliveryOrders();
    }

    // DEV ONLY
    async simulatePayment(orderId, paymentMethod, io = null) {
        const order = await orderRepository.updatePaymentStatus(orderId, 'completed');
        if (!order) {
            throw new Error("Commande non trouvée");
        }

        // 🔔 NOTIFICATIONS APRÈS PAIEMENT
        try {
            await this.notifyOrderPaid(orderId, io);
        } catch (err) {
            console.error('Erreur notification paiement:', err.message);
            // Ne pas bloquer le paiement si notification échoue
        }

        return order;
    }

    /**
     * Notifier tous les acteurs après confirmation paiement
     */
    async notifyOrderPaid(orderId, io = null) {
        // 1. Récupérer les détails de la commande
        const orderResult = await pool.query(
            `SELECT o.*, u.name as buyer_name, u.phone as buyer_phone
             FROM orders o
             JOIN users u ON o.user_id = u.id
             WHERE o.id = $1`,
            [orderId]
        );

        if (orderResult.rows.length === 0) {
            throw new Error('Commande introuvable');
        }

        const order = orderResult.rows[0];
        const buyerId = order.user_id;

        // 2. NOTIFICATION ACHETEUR
        await notificationService.send(
            buyerId,
            'order',
            'Commande confirmée ! 🎉',
            `Votre commande #${orderId} a été confirmée et sera bientôt traitée.`,
            { order_id: orderId, status: 'paid' },
            io
        );
        console.log(`   ✅ Notification acheteur envoyée (User #${buyerId})`);

        // 3. IDENTIFIER ET NOTIFIER VENDEUR(S)
        const itemsResult = await pool.query(
            `SELECT oi.product_name, p.seller_id
             FROM order_items oi
             LEFT JOIN products p ON oi.product_id = p.id
             WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL`,
            [orderId]
        );

        const sellers = [...new Set(itemsResult.rows.map(item => item.seller_id))];

        for (const sellerId of sellers) {
            await notificationService.send(
                sellerId,
                'order',
                'Nouvelle commande ! 💰',
                `Vous avez reçu une nouvelle commande #${orderId}`,
                { order_id: orderId, buyer_id: buyerId },
                io
            );
            console.log(`   ✅ Notification vendeur envoyée (Seller #${sellerId})`);
        }

        // 4. BROADCAST POUR LIVREURS (via Socket.IO uniquement)
        if (io) {
            io.emit('new_delivery_available', {
                order_id: orderId,
                delivery_address: order.delivery_address,
                total_amount: order.total_amount,
                created_at: new Date()
            });
            console.log(`   📡 Broadcast new_delivery_available émis`);
        }
    }
}

module.exports = new OrderService();
