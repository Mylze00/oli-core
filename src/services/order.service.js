const orderRepository = require('../repositories/order.repository');
const walletService = require('./wallet.service');
const notificationService = require('./notification.service');
const deliveryRepo = require('../repositories/delivery.repository');
const pool = require('../config/db');

class OrderService {
    async createOrder(userId, data, io = null) {
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

        // LOGIQUE PAIEMENT INSTANTANÉ (wallet & mobile_money)
        let paymentStatus = 'pending';
        let orderStatus = 'pending';

        if (paymentMethod === 'wallet') {
            try {
                await walletService.payOrder(userId, totalAmount);
                paymentStatus = 'paid';
                orderStatus = 'paid';
            } catch (err) {
                throw new Error(err.message || "Echec du paiement Wallet");
            }
        } else if (paymentMethod === 'mobile_money') {
            // Mobile Money : paiement simulé instantanément (en prod, intégrer l'API du provider)
            paymentStatus = 'paid';
            orderStatus = 'paid';
        }
        // 'card' reste pending → traité via StripePaymentPage + webhook

        // Créer la commande en base
        const order = await orderRepository.createOrder(
            userId,
            items,
            deliveryAddress || null,
            paymentMethod || 'wallet',
            parseFloat(deliveryFee) || 0
        );

        // Si paiement instantané réussi → MAJ statut + notifications + delivery
        if (paymentStatus === 'paid') {
            await orderRepository.updatePaymentStatus(order.id, 'paid');
            await orderRepository.updateOrderStatus(order.id, 'paid');
            order.status = 'paid';
            order.paymentStatus = 'paid';

            // 🔔 Notifications + création delivery_orders + broadcast Socket.IO
            try {
                await this.notifyOrderPaid(order.id, io);
                console.log(`   ✅ notifyOrderPaid exécuté pour commande #${order.id}`);
            } catch (notifErr) {
                console.error('⚠️ Erreur notifyOrderPaid (non-bloquante):', notifErr.message);
            }
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

        // 4. 🚚 CRÉER L'ENTRÉE delivery_orders POUR LES LIVREURS
        let deliveryOrder = null;
        try {
            deliveryOrder = await deliveryRepo.create({
                order_id: orderId,
                pickup_address: 'À déterminer',
                delivery_address: order.delivery_address || 'Non spécifiée',
                delivery_fee: 0,
                estimated_time: '45 min'
            });
            console.log(`   🚚 delivery_orders créé: ID ${deliveryOrder.id} pour commande #${orderId}`);
        } catch (deliveryErr) {
            console.error('⚠️ Erreur création delivery_orders:', deliveryErr.message);
        }

        // 5. BROADCAST POUR LIVREURS (via Socket.IO)
        if (io) {
            io.emit('new_delivery_available', {
                order_id: orderId,
                delivery_id: deliveryOrder?.id,
                delivery_address: order.delivery_address,
                total_amount: order.total_amount,
                created_at: new Date()
            });
            console.log(`   📡 Broadcast new_delivery_available émis`);
        }
    }
}

module.exports = new OrderService();
