const orderRepository = require('../repositories/order.repository');
const walletService = require('./wallet.service');
const notificationService = require('./notification.service');
const deliveryRepo = require('../repositories/delivery.repository');
const pool = require('../config/db');
const crypto = require('crypto');

class OrderService {
    /**
     * Génère un code de vérification à 6 caractères (lettres majuscules + chiffres)
     */
    generateVerificationCode() {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Pas de I/O/0/1 pour éviter confusion
        let code = '';
        const bytes = crypto.randomBytes(6);
        for (let i = 0; i < 6; i++) {
            code += chars[bytes[i] % chars.length];
        }
        return code;
    }

    async createOrder(userId, data, io = null) {
        const { items, deliveryAddress, paymentMethod, deliveryFee, deliveryMethodId } = data;

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
            paymentStatus = 'paid';
            orderStatus = 'paid';
        }

        // Créer la commande en base
        const order = await orderRepository.createOrder(
            userId,
            items,
            deliveryAddress || null,
            paymentMethod || 'wallet',
            parseFloat(deliveryFee) || 0,
            deliveryMethodId || null
        );

        // Si paiement instantané réussi → MAJ statut + notifications + delivery + codes
        if (paymentStatus === 'paid') {
            await orderRepository.updatePaymentStatus(order.id, 'paid');
            await orderRepository.updateOrderStatus(order.id, 'paid');
            order.status = 'paid';
            order.paymentStatus = 'paid';

            // Générer les codes de vérification
            const pickupCode = this.generateVerificationCode();
            const deliveryCode = this.generateVerificationCode();
            await pool.query(
                'UPDATE orders SET pickup_code = $1, delivery_code = $2 WHERE id = $3',
                [pickupCode, deliveryCode, order.id]
            );
            order.pickup_code = pickupCode;
            order.delivery_code = deliveryCode;
            console.log(`   🔑 Codes générés pour commande #${order.id}: pickup=${pickupCode}, delivery=${deliveryCode}`);

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
        const validStatuses = ['pending', 'paid', 'processing', 'ready', 'shipped', 'delivered', 'cancelled'];
        if (!validStatuses.includes(status)) {
            throw new Error("Statut invalide");
        }

        const order = await orderRepository.updateOrderStatus(orderId, status);
        if (!order) {
            throw new Error("Commande non trouvée");
        }

        // Mettre à jour les timestamps de tracking
        const timestampField = {
            'processing': 'processing_at',
            'ready': 'ready_at',
            'shipped': 'shipped_at',
            'delivered': 'delivered_at'
        }[status];

        if (timestampField) {
            await pool.query(
                `UPDATE orders SET ${timestampField} = NOW() WHERE id = $1`,
                [orderId]
            );
        }

        // Enregistrer dans l'historique
        try {
            await pool.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by_role)
                 VALUES ($1, $2, $3, 'system')`,
                [orderId, order.status, status]
            );
        } catch (e) {
            console.error('⚠️ Erreur historique statut:', e.message);
        }

        return order;
    }

    /**
     * Vendeur marque la commande comme "en préparation"
     */
    async markProcessing(orderId, sellerId, io = null) {
        const order = await this._getOrderForSeller(orderId, sellerId);

        if (!['paid'].includes(order.status)) {
            throw new Error("La commande doit être au statut 'paid' pour être mise en préparation");
        }

        await pool.query(
            "UPDATE orders SET status = 'processing', processing_at = NOW() WHERE id = $1",
            [orderId]
        );

        await this._logStatusChange(orderId, order.status, 'processing', sellerId, 'seller');

        // Notifier l'acheteur
        await notificationService.send(
            order.user_id, 'order',
            'Commande en préparation 📦',
            `Le vendeur prépare votre commande #${orderId}.`,
            { order_id: orderId, status: 'processing' }, io
        );

        // Notifier les livreurs (broadcast) que la commande est en cours de préparation
        if (io) {
            io.emit('order_preparing', {
                order_id: orderId,
                delivery_address: order.delivery_address,
                delivery_method: order.delivery_method_id,
                message: `Commande #${orderId} en préparation, bientôt prête pour collecte.`
            });
            console.log(`   📡 Broadcast order_preparing émis pour commande #${orderId}`);
        }

        return { ...order, status: 'processing' };
    }

    /**
     * Vendeur marque la commande comme "prête pour expédition"
     * Le pickup_code est révélé au livreur à ce moment
     * Génère les codes s'ils n'existent pas encore (commandes créées avant le système de codes)
     */
    async markReady(orderId, sellerId, io = null) {
        const order = await this._getOrderForSeller(orderId, sellerId);

        if (!['processing'].includes(order.status)) {
            throw new Error("La commande doit être en 'processing' pour être marquée prête");
        }

        // Générer les codes de vérification s'ils n'existent pas
        let pickupCode = order.pickup_code;
        let deliveryCode = order.delivery_code;

        if (!pickupCode || !deliveryCode) {
            pickupCode = pickupCode || this.generateVerificationCode();
            deliveryCode = deliveryCode || this.generateVerificationCode();
            await pool.query(
                'UPDATE orders SET pickup_code = $1, delivery_code = $2 WHERE id = $3',
                [pickupCode, deliveryCode, orderId]
            );
            console.log(`   🔑 Codes générés pour commande #${orderId}: pickup=${pickupCode}, delivery=${deliveryCode}`);
        }

        await pool.query(
            "UPDATE orders SET status = 'ready', ready_at = NOW() WHERE id = $1",
            [orderId]
        );

        await this._logStatusChange(orderId, order.status, 'ready', sellerId, 'seller');

        // Notifier l'acheteur
        await notificationService.send(
            order.user_id, 'order',
            'Commande prête ! 🎉',
            `Votre commande #${orderId} est prête et en attente du livreur.`,
            { order_id: orderId, status: 'ready' }, io
        );

        // Notifier les livreurs (broadcast)
        if (io) {
            io.emit('order_ready_for_pickup', {
                order_id: orderId,
                pickup_code: pickupCode,
                delivery_address: order.delivery_address
            });
        }

        return { ...order, status: 'ready', pickup_code: pickupCode, delivery_code: deliveryCode };
    }

    /**
     * Valide le retrait avec le pickup_code
     * Circuit A (livreur) : ready → shipped + sync delivery_orders
     * Circuit B (Pick & Go) : ready → delivered directement (pas de livreur)
     */
    async verifyPickup(orderId, code, verifierId, io = null) {
        const result = await pool.query(
            'SELECT * FROM orders WHERE id = $1', [orderId]
        );
        if (result.rows.length === 0) throw new Error('Commande non trouvée');
        const order = result.rows[0];

        if (order.status !== 'ready') {
            throw new Error("La commande doit être au statut 'ready' pour valider le pickup");
        }

        if (order.pickup_code !== code.toUpperCase()) {
            throw new Error('Code de pickup invalide');
        }

        const isPickAndGo = order.delivery_method_id === 'pick_go';

        if (isPickAndGo) {
            // Circuit B — Pick & Go : directement DELIVERED
            await pool.query(
                "UPDATE orders SET status = 'delivered', delivered_at = NOW() WHERE id = $1",
                [orderId]
            );
            await this._logStatusChange(orderId, 'ready', 'delivered', verifierId, 'seller');

            // Notifier l'acheteur
            await notificationService.send(
                order.user_id, 'order',
                'Commande récupérée ✅',
                `Votre commande #${orderId} a été récupérée avec succès au guichet.`,
                { order_id: orderId, status: 'delivered' }, io
            );

            return { ...order, status: 'delivered', verified_pickup: true, circuit: 'pick_go' };
        }

        // Circuit A — Livreur : ready → shipped
        await pool.query(
            "UPDATE orders SET status = 'shipped', shipped_at = NOW() WHERE id = $1",
            [orderId]
        );

        // Sync delivery_orders → picked_up
        await pool.query(
            "UPDATE delivery_orders SET status = 'picked_up', updated_at = NOW() WHERE order_id = $1",
            [orderId]
        );

        await this._logStatusChange(orderId, 'ready', 'shipped', verifierId, 'deliverer');

        // Notifier l'acheteur : le colis est en route + lui envoyer le delivery_code
        await notificationService.send(
            order.user_id, 'order',
            'Colis en route ! 🚚',
            `Votre commande #${orderId} est en cours de livraison. Votre code de réception : ${order.delivery_code}`,
            { order_id: orderId, status: 'shipped', delivery_code: order.delivery_code }, io
        );

        return { ...order, status: 'shipped', verified_pickup: true, circuit: 'deliverer' };
    }

    /**
     * Valide la livraison/remise avec le delivery_code
     * Circuit A (livreur) : acheteur confirme réception (status: shipped → delivered)
     * Circuit C (Hand Delivery) : vendeur confirme remise (status: processing → delivered)
     */
    async verifyDelivery(orderId, code, userId, io = null) {
        // Permettre au vendeur OU à l'acheteur de vérifier
        const result = await pool.query(
            'SELECT * FROM orders WHERE id = $1', [orderId]
        );
        if (result.rows.length === 0) throw new Error('Commande non trouvée');
        const order = result.rows[0];

        const isHandDelivery = order.delivery_method_id === 'hand_delivery';
        const isBuyer = order.user_id === userId;

        // Vérifier que l'appelant est autorisé
        if (!isBuyer && !isHandDelivery) {
            // Pour Circuit A, seul l'acheteur peut confirmer
            throw new Error('Seul l\'acheteur peut confirmer la réception');
        }

        // Pour Hand Delivery, vérifier que c'est le vendeur
        if (isHandDelivery && !isBuyer) {
            const sellerCheck = await pool.query(
                `SELECT DISTINCT p.seller_id FROM order_items oi
                 JOIN products p ON oi.product_id::integer = p.id
                 WHERE oi.order_id = $1 AND p.seller_id = $2`,
                [orderId, userId]
            );
            if (sellerCheck.rows.length === 0) {
                throw new Error('Accès non autorisé');
            }
        }

        // Vérifier le statut autorisé
        const allowedStatuses = isHandDelivery ? ['processing', 'shipped'] : ['shipped'];
        if (!allowedStatuses.includes(order.status)) {
            throw new Error(`La commande doit être au statut '${allowedStatuses.join("' ou '")}' pour valider la livraison`);
        }

        if (order.delivery_code !== code.toUpperCase()) {
            throw new Error('Code de livraison invalide');
        }

        await pool.query(
            "UPDATE orders SET status = 'delivered', delivered_at = NOW() WHERE id = $1",
            [orderId]
        );

        // Sync delivery_orders → delivered (seulement si existe)
        await pool.query(
            "UPDATE delivery_orders SET status = 'delivered', updated_at = NOW() WHERE order_id = $1",
            [orderId]
        );

        const previousStatus = order.status;
        const role = isBuyer ? 'buyer' : 'seller';
        await this._logStatusChange(orderId, previousStatus, 'delivered', userId, role);

        // Notifier le vendeur (si l'acheteur confirme) ou l'acheteur (si le vendeur confirme)
        if (isBuyer) {
            // Notifier le vendeur
            const sellerResult = await pool.query(
                `SELECT DISTINCT p.seller_id FROM order_items oi
                 JOIN products p ON oi.product_id::integer = p.id
                 WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL`,
                [orderId]
            );
            for (const row of sellerResult.rows) {
                await notificationService.send(
                    row.seller_id, 'order',
                    'Commande livrée ✅',
                    `La commande #${orderId} a été livrée avec succès.`,
                    { order_id: orderId, status: 'delivered' }, io
                );
            }
        } else {
            // Hand Delivery: notifier l'acheteur
            await notificationService.send(
                order.user_id, 'order',
                'Commande reçue ✅',
                `Votre commande #${orderId} a été remise en main propre avec succès.`,
                { order_id: orderId, status: 'delivered' }, io
            );
        }

        return { ...order, status: 'delivered', verified_delivery: true, circuit: isHandDelivery ? 'hand_delivery' : 'deliverer' };
    }

    /**
     * Récupère la timeline complète d'une commande
     */
    async getOrderTracking(orderId, userId) {
        // Vérifier que l'utilisateur a accès (acheteur ou vendeur)
        const orderResult = await pool.query(
            `SELECT o.*, u.name as buyer_name
             FROM orders o
             JOIN users u ON o.user_id = u.id
             WHERE o.id = $1`,
            [orderId]
        );
        if (orderResult.rows.length === 0) throw new Error('Commande non trouvée');
        const order = orderResult.rows[0];

        // Vérifier permission : acheteur, vendeur, ou livreur
        const isBuyer = order.user_id === userId;
        let isSeller = false;
        let isDeliverer = false;
        if (!isBuyer) {
            const sellerCheck = await pool.query(
                `SELECT 1 FROM order_items oi
                 JOIN products p ON oi.product_id::integer = p.id
                 WHERE oi.order_id = $1 AND p.seller_id = $2 LIMIT 1`,
                [orderId, userId]
            );
            isSeller = sellerCheck.rows.length > 0;
        }
        if (!isBuyer && !isSeller) {
            const delivererCheck = await pool.query(
                `SELECT 1 FROM delivery_orders WHERE order_id = $1 AND deliverer_id = $2 LIMIT 1`,
                [orderId, userId]
            );
            isDeliverer = delivererCheck.rows.length > 0;
        }

        if (!isBuyer && !isSeller && !isDeliverer) {
            throw new Error('Accès non autorisé à cette commande');
        }

        // Historique des statuts
        const historyResult = await pool.query(
            `SELECT * FROM order_status_history
             WHERE order_id = $1 ORDER BY created_at ASC`,
            [orderId]
        );

        // Construire la timeline
        const steps = [
            {
                step: 1,
                label: 'Commande reçue',
                status: 'paid',
                completed: ['paid', 'processing', 'ready', 'shipped', 'delivered'].includes(order.status),
                timestamp: order.created_at
            },
            {
                step: 2,
                label: 'En préparation',
                status: 'processing',
                completed: ['processing', 'ready', 'shipped', 'delivered'].includes(order.status),
                timestamp: order.processing_at
            },
            {
                step: 3,
                label: 'Prêt pour expédition',
                status: 'ready',
                completed: ['ready', 'shipped', 'delivered'].includes(order.status),
                timestamp: order.ready_at
            },
            {
                step: 4,
                label: 'Expédition en cours',
                status: 'shipped',
                completed: ['shipped', 'delivered'].includes(order.status),
                timestamp: order.shipped_at
            },
            {
                step: 5,
                label: 'Livré',
                status: 'delivered',
                completed: order.status === 'delivered',
                timestamp: order.delivered_at
            }
        ];

        return {
            order_id: order.id,
            current_status: order.status,
            delivery_method: order.delivery_method_id,
            delivery_address: order.delivery_address,
            buyer_name: order.buyer_name,
            // Codes : acheteur voit delivery_code, vendeur/livreur voient pickup_code
            pickup_code: (isSeller || isDeliverer) ? order.pickup_code : null,
            delivery_code: isBuyer ? order.delivery_code : null,
            steps,
            history: historyResult.rows,
            created_at: order.created_at
        };
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

        // Générer les codes si pas encore fait
        const pickupCode = this.generateVerificationCode();
        const deliveryCode = this.generateVerificationCode();
        await pool.query(
            'UPDATE orders SET pickup_code = $1, delivery_code = $2 WHERE id = $3 AND pickup_code IS NULL',
            [pickupCode, deliveryCode, orderId]
        );

        let notificationError = null;
        try {
            await this.notifyOrderPaid(orderId, io);
        } catch (err) {
            notificationError = err.message + ' | Stack: ' + err.stack;
            console.error('Erreur notification paiement:', err.message, err.stack);
        }

        order.notificationError = notificationError;
        return order;
    }

    /**
     * Notifier tous les acteurs après confirmation paiement
     */
    async notifyOrderPaid(orderId, io = null) {
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

        // NOTIFICATION ACHETEUR
        await notificationService.send(
            buyerId, 'order',
            'Commande confirmée ! 🎉',
            `Votre commande #${orderId} a été confirmée et sera bientôt traitée.`,
            { order_id: orderId, status: 'paid' }, io
        );
        console.log(`   ✅ Notification acheteur envoyée (User #${buyerId})`);

        // IDENTIFIER ET NOTIFIER VENDEUR(S) + envoyer pickup_code
        try {
            const itemsResult = await pool.query(
                `SELECT oi.product_name, p.seller_id
                 FROM order_items oi
                 LEFT JOIN products p ON oi.product_id::integer = p.id
                 WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL`,
                [orderId]
            );

            const sellers = [...new Set(itemsResult.rows.map(item => item.seller_id))];

            for (const sellerId of sellers) {
                await notificationService.send(
                    sellerId, 'order',
                    'Nouvelle commande ! 💰',
                    `Vous avez reçu une nouvelle commande #${orderId}. Préparez-la et marquez-la comme prête.`,
                    { order_id: orderId, buyer_id: buyerId, pickup_code: order.pickup_code }, io
                );
                console.log(`   ✅ Notification vendeur envoyée (Seller #${sellerId})`);
            }
        } catch (sellerErr) {
            console.error('⚠️ Erreur notification vendeur (non-bloquante):', sellerErr.message);
        }

        // CRÉER L'ENTRÉE delivery_orders POUR LES LIVREURS
        // Uniquement pour Circuit A (modes avec livreur Oli)
        const CIRCUIT_A_MODES = ['oli_express', 'oli_standard', 'partner', 'free'];
        const deliveryMethod = order.delivery_method_id;
        const needsDeliverer = !deliveryMethod || CIRCUIT_A_MODES.includes(deliveryMethod);

        let deliveryOrder = null;
        if (needsDeliverer) {
            // R4: Récupérer l'adresse du vendeur depuis la table addresses
            let pickupAddress = 'À déterminer';
            try {
                const sellerAddr = await pool.query(
                    `SELECT COALESCE(
                        CONCAT_WS(', ',
                            NULLIF(a.avenue, ''),
                            NULLIF(a.numero, ''),
                            NULLIF(a.quartier, ''),
                            NULLIF(a.commune, ''),
                            NULLIF(a.ville, '')
                        ),
                        a.address,
                        u.name
                    ) as full_address
                    FROM order_items oi
                    JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
                    LEFT JOIN users u ON u.id = p.seller_id
                    LEFT JOIN addresses a ON a.user_id = p.seller_id
                    WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL
                    ORDER BY a.created_at DESC
                    LIMIT 1`,
                    [orderId]
                );
                if (sellerAddr.rows.length > 0 && sellerAddr.rows[0].full_address) {
                    pickupAddress = sellerAddr.rows[0].full_address;
                }
            } catch (addrErr) {
                console.error('⚠️ Erreur récupération adresse vendeur:', addrErr.message);
            }

            try {
                deliveryOrder = await deliveryRepo.create({
                    order_id: orderId,
                    pickup_address: pickupAddress,
                    delivery_address: order.delivery_address || 'Non spécifiée',
                    delivery_fee: parseFloat(order.delivery_fee) || 0,
                    estimated_time: deliveryMethod === 'oli_express' ? '1-2h' : '45 min'
                });
                console.log(`   🚚 delivery_orders créé: ID ${deliveryOrder.id} pour commande #${orderId} (mode: ${deliveryMethod}, pickup: ${pickupAddress})`);
            } catch (deliveryErr) {
                console.error('⚠️ Erreur création delivery_orders:', deliveryErr.message);
            }

            // BROADCAST POUR LIVREURS (via Socket.IO)
            if (io) {
                io.emit('new_delivery_available', {
                    order_id: orderId,
                    delivery_id: deliveryOrder?.id,
                    delivery_address: order.delivery_address,
                    total_amount: order.total_amount,
                    delivery_method: deliveryMethod,
                    created_at: new Date()
                });
                console.log(`   📡 Broadcast new_delivery_available émis`);
            }
        } else {
            console.log(`   ℹ️ Pas de delivery_orders pour mode "${deliveryMethod}" (Circuit B/C)`);
        }
    }

    // --- Helpers privés ---

    async _getOrderForSeller(orderId, sellerId) {
        const result = await pool.query(
            `SELECT o.* FROM orders o
             JOIN order_items oi ON oi.order_id = o.id
             JOIN products p ON oi.product_id::integer = p.id
             WHERE o.id = $1 AND p.seller_id = $2
             LIMIT 1`,
            [orderId, sellerId]
        );
        if (result.rows.length === 0) {
            throw new Error('Commande non trouvée ou non autorisée');
        }
        return result.rows[0];
    }

    async _logStatusChange(orderId, prevStatus, newStatus, changedBy, role) {
        try {
            await pool.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, $3, $4, $5)`,
                [orderId, prevStatus, newStatus, changedBy, role]
            );
        } catch (e) {
            console.error('⚠️ Erreur log statut:', e.message);
        }
    }
}

module.exports = new OrderService();
