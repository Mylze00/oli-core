const orderRepository = require('../repositories/order.repository');
const walletService = require('./wallet.service');
const notificationService = require('./notification.service');
const deliveryRepo = require('../repositories/delivery.repository');
const exchangeRateService = require('./exchange-rate.service');
const refundService = require('./refund.service');
const { orderAmountToWallet } = require('../utils/order-currency');

/** Marge ajoutée à une recharge Mobile Money de commande (reste sur le wallet). */
const MOBILE_MONEY_ROUNDING_FC = 1;
/** Modes sans livreur Oli : retrait au guichet et remise en main propre. */
const NO_DELIVERER_MODES = ['pick_go', 'hand_delivery'];
/** Commandes en cours de règlement Mobile Money sur cette instance. */
const settlingOrders = new Set();
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
            throw this._badRequest("Items requis");
        }
        // Le paiement par carte n'est qu'une simulation : une commande créée ainsi ne serait jamais réglée
        if (!['wallet', 'mobile_money'].includes(paymentMethod)) {
            throw this._badRequest('Ce moyen de paiement sera bientôt disponible. Payez avec votre wallet Oli ou Mobile Money.');
        }

        // [SÉCU C1/C2] Les prix viennent de la base, jamais du client.
        const { items: pricedItems, itemsTotal } = await this._priceItemsFromCatalogue(items, userId);

        // [SÉCU C2] Frais de livraison : jamais négatifs (le recalcul par mode reste à faire)
        const safeDeliveryFee = Math.max(0, parseFloat(deliveryFee) || 0);
        const totalAmount = itemsTotal + safeDeliveryFee;

        // Taux figé pour toute la vie de la commande (débit, crédits et remboursement)
        const exchangeRate = await this._getOrderExchangeRate();
        const walletAmount = orderAmountToWallet(totalAmount, exchangeRate);

        // LOGIQUE PAIEMENT INSTANTANÉ (wallet & mobile_money)
        let paymentStatus = 'pending';
        let orderStatus = 'pending';

        if (paymentMethod === 'wallet') {
            try {
                // Débiter le wallet avant de créer la commande en base
                await walletService.payOrder(userId, walletAmount, null); // orderId connu après création
                paymentStatus = 'completed';
                orderStatus = 'paid';
            } catch (err) {
                // Relancer l'erreur avec message clair (ex: Solde insuffisant)
                throw this._badRequest(err.message || 'Échec du paiement Wallet');
            }
        } else if (paymentMethod === 'mobile_money') {
            // Mobile Money = flux asynchrone : on crée la commande en 'pending'
            // et on attend la confirmation de l'API Mobile Money
            paymentStatus = 'pending';
            orderStatus = 'pending';
        }

        // Créer la commande en base
        let order;
        try {
            order = await orderRepository.createOrder(
                userId,
                pricedItems,
                deliveryAddress || null,
                paymentMethod || 'wallet',
                safeDeliveryFee,
                deliveryMethodId || null,
                exchangeRate
            );
        } catch (createErr) {
            // [FIN C2] Le wallet a déjà été débité : on rembourse si la commande n'existe pas
            if (paymentStatus === 'completed') {
                const walletRepository = require('../repositories/wallet.repository');
                await walletRepository.performDeposit(userId, walletAmount, {
                    type: 'refund',
                    provider: 'WALLET',
                    reference: `REFUND_ORDER_FAIL_${userId}_${Date.now()}`,
                    description: `Remboursement : commande non créée (${createErr.message})`,
                });
                console.error(`↩️ Commande non créée : remboursement de ${walletAmount} FC à l'utilisateur #${userId}`);
            }
            throw createErr;
        }

        // Pour Wallet : mettre à jour la référence de transaction avec l'ID commande réel
        if (paymentMethod === 'wallet' && paymentStatus === 'completed') {
            // Mettons à jour la description de la transaction wallet avec le vrai order.id
            // (non-bloquant, best-effort)
            const pool = require('../config/db');
            pool.query(
                `UPDATE wallet_transactions SET reference = $1, order_id = $2, description = $3
                 WHERE user_id = $4 AND reference = $5 AND type = 'payment'`,
                [
                    `ORDER_${order.id}`,
                    order.id,
                    `Paiement commande #${order.id}`,
                    userId,
                    `ORDER_null`
                ]
            ).catch(e => console.warn('⚠️ Mise à jour référence wallet tx (non-bloquant):', e.message));
        }

        // Si paiement instantané réussi → MAJ statut + notifications + delivery + codes
        if (paymentStatus === 'completed') {
            await orderRepository.updatePaymentStatus(order.id, 'completed');
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

    /**
     * Devis exact d'une commande, calculé comme à la création : prix catalogue,
     * livraison, taux du jour, montant débité en FC et frais Mobile Money.
     */
    async quoteOrder(userId, { items, deliveryFee }) {
        if (!Array.isArray(items) || items.length === 0) throw this._badRequest('Items requis');
        const { items: pricedItems, itemsTotal } = await this._priceItemsFromCatalogue(items, userId);
        const safeDeliveryFee = Math.max(0, parseFloat(deliveryFee) || 0);
        const totalUsd = itemsTotal + safeDeliveryFee;
        const exchangeRate = await this._getOrderExchangeRate();
        const totalFC = orderAmountToWallet(totalUsd, exchangeRate);
        const { FEES } = require('../config/index');
        // Même calcul que la recharge lancée par payOrderByMobileMoney
        const mobileMoneyNetFC = totalFC + MOBILE_MONEY_ROUNDING_FC;
        const mobileMoneyFeeFC = MOBILE_MONEY_ROUNDING_FC
            + Math.round(mobileMoneyNetFC * FEES.AGGREGATOR_DEPOSIT_RATE)
            + Math.round(mobileMoneyNetFC * FEES.OLI_DEPOSIT_RATE);
        const walletBalanceFC = parseFloat(await walletService.getBalance(userId)) || 0;

        return {
            items: pricedItems.map((it) => ({
                productId: it.productId,
                variantId: it.variantId || null,
                productName: it.productName,
                quantity: it.quantity,
                unitPriceUsd: it.price,
                lineTotalFC: orderAmountToWallet(it.price * it.quantity, exchangeRate),
            })),
            itemsTotalUsd: itemsTotal,
            deliveryFeeUsd: safeDeliveryFee,
            itemsTotalFC: orderAmountToWallet(itemsTotal, exchangeRate),
            deliveryFeeFC: orderAmountToWallet(safeDeliveryFee, exchangeRate),
            totalUsd,
            totalFC,
            exchangeRate,
            walletBalanceFC,
            mobileMoneyFeeFC,
            mobileMoneyTotalFC: totalFC + mobileMoneyFeeFC,
        };
    }

    /**
     * Paiement d'une commande par Mobile Money : une recharge Unipesa du montant exact
     * (frais de recharge en plus) est lancée ; à la confirmation signée par Unipesa,
     * la commande est réglée depuis le wallet (voir settleMobileMoneyOrder).
     */
    async payOrderByMobileMoney(userId, orderId, phone) {
        const cleanPhone = typeof phone === 'string' ? phone.replace(/[\s.-]/g, '') : '';
        if (!/^\+?\d{9,15}$/.test(cleanPhone)) throw this._badRequest('Numéro Mobile Money invalide');

        const { rows } = await pool.query(
            'SELECT id, user_id, total_amount, exchange_rate, payment_status, payment_method, status FROM orders WHERE id = $1',
            [orderId]
        );
        const order = rows[0];
        if (!order || Number(order.user_id) !== Number(userId)) {
            const notFound = new Error('Commande non trouvée');
            notFound.status = 404;
            throw notFound;
        }
        if (order.payment_status === 'completed') throw this._badRequest('Commande déjà payée');
        if (order.status === 'cancelled') throw this._badRequest('Commande annulée');

        const amountFC = orderAmountToWallet(order.total_amount, order.exchange_rate);
        const unipesaService = require('./unipesa.service');
        // +1 FC : le crédit (brut / 1,06) ne doit jamais tomber sous le montant de la commande à cause des arrondis
        const result = await unipesaService.initiateDeposit(userId, cleanPhone, amountFC + MOBILE_MONEY_ROUNDING_FC, order.exchange_rate, { orderId: order.id });
        await pool.query("UPDATE orders SET payment_method = 'mobile_money', updated_at = NOW() WHERE id = $1", [order.id]);
        return result;
    }

    /**
     * Appelé après la confirmation d'une recharge Unipesa liée à une commande :
     * le wallet vient d'être crédité, la commande est réglée depuis celui-ci.
     * Si le règlement échoue, l'argent reste sur le wallet de l'acheteur.
     */
    async settleMobileMoneyOrder(orderId, userId, io = null) {
        // Webhook rejoué en même temps : une seule exécution par commande
        if (settlingOrders.has(orderId)) return { settled: false, reason: 'in_progress' };
        settlingOrders.add(orderId);
        try {
            return await this._settleMobileMoneyOrder(orderId, userId, io);
        } finally {
            settlingOrders.delete(orderId);
        }
    }

    async _settleMobileMoneyOrder(orderId, userId, io) {
        const { rows } = await pool.query(
            'SELECT id, user_id, total_amount, exchange_rate, payment_status, status FROM orders WHERE id = $1',
            [orderId]
        );
        const order = rows[0];
        if (!order || Number(order.user_id) !== Number(userId)) return { settled: false, reason: 'order_not_found' };
        if (order.payment_status === 'completed') return { settled: true, alreadyPaid: true };
        if (order.status === 'cancelled') return { settled: false, reason: 'order_cancelled' };

        const amountFC = orderAmountToWallet(order.total_amount, order.exchange_rate);
        await walletService.payOrder(userId, amountFC, order.id);
        await this._markOrderPaid(order.id, io);
        return { settled: true };
    }

    /** Commande réglée : statuts, codes de retrait et de livraison, puis notifications. */
    async _markOrderPaid(orderId, io = null) {
        await orderRepository.updatePaymentStatus(orderId, 'completed');
        await orderRepository.updateOrderStatus(orderId, 'paid');
        await pool.query(
            'UPDATE orders SET pickup_code = $1, delivery_code = $2 WHERE id = $3 AND pickup_code IS NULL',
            [this.generateVerificationCode(), this.generateVerificationCode(), orderId]
        );
        try {
            await this.notifyOrderPaid(orderId, io);
        } catch (err) {
            console.error('⚠️ Erreur notifyOrderPaid (non-bloquante):', err.message);
        }
    }

    /**
     * Erreur métier renvoyée au client avec un statut 400 (et non 500).
     */
    _badRequest(message) {
        const err = new Error(message);
        err.status = 400;
        return err;
    }

    /**
     * Récupère le taux USD → FC à figer sur la commande.
     * Sans taux fiable, la commande est refusée avant tout débit.
     */
    async _getOrderExchangeRate() {
        try {
            return await exchangeRateService.getRateForOrder();
        } catch (err) {
            console.error('❌ Commande refusée, taux de change indisponible:', err.message);
            const unavailable = new Error('Le taux de change est momentanément indisponible. Réessayez dans quelques instants.');
            unavailable.status = 503;
            throw unavailable;
        }
    }

    /**
     * [SÉCU C1/C2] Recalcule les prix à partir de la table `products`.
     * Seuls productId et quantity sont lus côté client ; le prix, le nom et le vendeur
     * sont relus en base. Refuse les produits non actifs, les prix invalides et les
     * quantités non entières ou hors bornes.
     *
     * @returns {Promise<{items: Array, itemsTotal: number}>}
     */
    /** Variantes actives demandées par le panier, indexées par identifiant. */
    async _loadVariants(items) {
        const ids = [...new Set(items.map((i) => i.variantId).filter(Boolean).map(String))];
        if (!ids.length) return new Map();
        const { rows } = await pool.query(
            `SELECT id::text AS id, product_id, variant_value, price_adjustment
             FROM product_variants WHERE id::text = ANY($1::text[]) AND is_active = TRUE`,
            [ids]
        );
        return new Map(rows.map((v) => [v.id, v]));
    }

    async _priceItemsFromCatalogue(items, buyerId) {
        const MAX_QTY_PER_LINE = 1000;
        const parsed = items.map((item) => {
            const productId = parseInt(item?.productId, 10);
            const quantity = Number(item?.quantity);
            if (!Number.isInteger(productId) || productId <= 0) {
                throw this._badRequest("productId invalide");
            }
            if (!Number.isInteger(quantity) || quantity <= 0 || quantity > MAX_QTY_PER_LINE) {
                throw this._badRequest(`Quantité invalide (entier entre 1 et ${MAX_QTY_PER_LINE})`);
            }
            return { ...item, productId, quantity };
        });

        const uniqueIds = [...new Set(parsed.map((i) => i.productId))];
        // Le prix facturé est celui affiché : promotion en cours comprise
        const res = await pool.query(`
            SELECT id, name, price, status,
                   CASE WHEN discount_price > 0 AND discount_price < price
                             AND (discount_start_date IS NULL OR discount_start_date <= NOW())
                             AND (discount_end_date IS NULL OR discount_end_date >= NOW())
                        THEN discount_price END AS active_discount_price
            FROM products WHERE id = ANY($1::int[])
        `, [uniqueIds]);
        const byId = new Map(res.rows.map((p) => [p.id, p]));
        const variantsById = await this._loadVariants(parsed);

        const videosById = await this._loadOriginVideos(parsed);

        const pricedItems = parsed.map((item) => {
            const product = byId.get(item.productId);
            if (!product) {
                throw this._badRequest(`Produit introuvable (#${item.productId})`);
            }
            if (product.status !== 'active') {
                throw this._badRequest(`Produit indisponible : ${product.name}`);
            }
            const basePrice = parseFloat(product.active_discount_price ?? product.price);
            // Variante choisie : son supplément s'ajoute, et elle doit appartenir au produit
            let variant = null;
            if (item.variantId) {
                variant = variantsById.get(String(item.variantId));
                if (!variant || variant.product_id !== item.productId) {
                    throw this._badRequest(`Variante indisponible pour ${product.name}`);
                }
            }
            const price = Math.round((basePrice + (variant ? parseFloat(variant.price_adjustment) || 0 : 0)) * 100) / 100;
            if (!Number.isFinite(price) || price <= 0) {
                throw this._badRequest(`Prix invalide pour le produit #${item.productId}`);
            }
            // La commission vidéo n'est retenue que si la vidéo présente bien ce produit
            // et que l'acheteur n'est pas lui-même le créateur de la vidéo.
            const originVideo = videosById.get(parseInt(item.originVideoId, 10));
            const isValidOrigin = originVideo
                && originVideo.product_id === item.productId
                && String(originVideo.user_id) !== String(buyerId);

            return {
                ...item,
                productName: variant ? `${product.name} (${variant.variant_value})` : product.name,
                price,
                originVideoId: isValidOrigin ? originVideo.id : null,
            };
        });

        const itemsTotal = pricedItems.reduce((acc, it) => acc + it.price * it.quantity, 0);
        return { items: pricedItems, itemsTotal };
    }

    /**
     * Charge les vidéos actives citées comme origine des articles d'une commande.
     * @returns {Promise<Map<number, {id: number, user_id: number, product_id: number}>>}
     */
    async _loadOriginVideos(items) {
        const videoIds = [...new Set(
            items
                .map((item) => parseInt(item.originVideoId, 10))
                .filter((id) => Number.isInteger(id) && id > 0)
        )];
        if (videoIds.length === 0) return new Map();

        const res = await pool.query(
            `SELECT id, user_id, product_id FROM video_sales
             WHERE id = ANY($1::int[]) AND status = 'active'`,
            [videoIds]
        );
        return new Map(res.rows.map((video) => [video.id, video]));
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
        await refundService.assertNoOpenRefund(orderId);

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
     * Génère les codes pickup + delivery, et notifie le livreur
     * Le vendeur voit le pickup_code, l'acheteur recevra le delivery_code plus tard
     */
    async markProcessing(orderId, sellerId, io = null) {
        await refundService.assertNoOpenRefund(orderId);

        const order = await this._getOrderForSeller(orderId, sellerId);

        if (!['paid'].includes(order.status)) {
            throw new Error("La commande doit être au statut 'paid' pour être mise en préparation");
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Générer les codes de vérification
            const pickupCode = order.pickup_code || this.generateVerificationCode();
            const deliveryCode = order.delivery_code || this.generateVerificationCode();

            await client.query(
                `UPDATE orders SET 
                    status = 'processing', 
                    processing_at = NOW(),
                    pickup_code = $2,
                    delivery_code = $3
                 WHERE id = $1`,
                [orderId, pickupCode, deliveryCode]
            );
            console.log(`   🔑 Codes: pickup=${pickupCode}, delivery=${deliveryCode} pour commande #${orderId}`);

            await client.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, $3, $4, $5)`,
                [orderId, order.status, 'processing', sellerId, 'seller']
            );

            // Créer l'entrée delivery_orders + broadcast aux livreurs
            const deliveryMethod = order.delivery_method_id;
            const needsDeliverer = this._needsDeliverer(deliveryMethod);

            if (needsDeliverer) {
                // Vérifier qu'il n'y a pas déjà une entrée delivery_orders pour cette commande
                const existingDelivery = await client.query(
                    'SELECT id FROM delivery_orders WHERE order_id = $1 LIMIT 1',
                    [orderId]
                );

                if (existingDelivery.rows.length > 0) {
                    console.log(`   ⚠️ delivery_orders déjà existant pour commande #${orderId}, skip INSERT`);
                } else {
                    // Récupérer l'adresse du vendeur
                    let pickupAddress = 'À déterminer';
                    try {
                        const sellerAddr = await client.query(
                            `SELECT COALESCE(
                            CONCAT_WS(', ', NULLIF(a.avenue, ''), NULLIF(a.numero, ''), NULLIF(a.quartier, ''), NULLIF(a.commune, ''), NULLIF(a.ville, '')),
                            a.address, u.name
                        ) as full_address
                        FROM order_items oi
                        JOIN products p ON p.id = CAST(oi.product_id AS INTEGER)
                        LEFT JOIN users u ON u.id = p.seller_id
                        LEFT JOIN addresses a ON a.user_id = p.seller_id
                        WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL
                        ORDER BY a.created_at DESC LIMIT 1`,
                            [orderId]
                        );
                        if (sellerAddr.rows.length > 0 && sellerAddr.rows[0].full_address) {
                            pickupAddress = sellerAddr.rows[0].full_address;
                        }
                    } catch (addrErr) {
                        console.error('⚠️ Erreur adresse vendeur:', addrErr.message);
                    }

                    await client.query(`
                    INSERT INTO delivery_orders (
                        order_id, pickup_address, delivery_address,
                        delivery_fee, estimated_time, status, created_at
                    ) VALUES ($1, $2, $3, $4, $5, 'pending', NOW())
                `, [orderId, pickupAddress, order.delivery_address || 'Non spécifiée',
                        parseFloat(order.delivery_fee) || 0,
                        deliveryMethod === 'oli_express' ? '45 min' : '1-2h']);
                    console.log(`   🚚 delivery_orders créé pour commande #${orderId}`);
                }
            }

            await client.query('COMMIT');

            // Non-transactional: notifications + Socket.IO (ne doivent pas bloquer)
            try {
                await notificationService.send(
                    order.user_id, 'order',
                    'Commande en préparation 📦',
                    `Le vendeur prépare votre commande #${orderId}.`,
                    { order_id: orderId, status: 'processing' }, io
                );
            } catch (notifErr) {
                console.error('⚠️ Erreur notification (non-bloquante):', notifErr.message);
            }

            if (needsDeliverer && io) {
                io.to('deliverers').emit('new_delivery_available', {
                    order_id: orderId,
                    delivery_address: order.delivery_address,
                    total_amount: order.total_amount,
                    delivery_method: deliveryMethod,
                    message: `Nouvelle commande #${orderId} disponible pour livraison !`
                });
                console.log(`   📡 Broadcast new_delivery_available émis pour commande #${orderId}`);
            }

            // Réponse destinée au vendeur : sans le code de réception de l'acheteur
            const { delivery_code: _buyerCode, ...sellerView } = order;
            return { ...sellerView, status: 'processing', pickup_code: pickupCode };
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * Vendeur marque la commande comme "prête pour expédition"
     * Le pickup_code est révélé au livreur à ce moment
     * Génère les codes s'ils n'existent pas encore (commandes créées avant le système de codes)
     */
    async markReady(orderId, sellerId, io = null) {
        await refundService.assertNoOpenRefund(orderId);

        const order = await this._getOrderForSeller(orderId, sellerId);

        if (!['processing'].includes(order.status)) {
            throw new Error("La commande doit être en 'processing' pour être marquée prête");
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Générer les codes de vérification s'ils n'existent pas
            let pickupCode = order.pickup_code;
            let deliveryCode = order.delivery_code;

            if (!pickupCode || !deliveryCode) {
                pickupCode = pickupCode || this.generateVerificationCode();
                deliveryCode = deliveryCode || this.generateVerificationCode();
                await client.query(
                    'UPDATE orders SET pickup_code = $1, delivery_code = $2 WHERE id = $3',
                    [pickupCode, deliveryCode, orderId]
                );
                console.log(`   🔑 Codes générés pour commande #${orderId}: pickup=${pickupCode}, delivery=${deliveryCode}`);
            }

            await client.query(
                "UPDATE orders SET status = 'ready', ready_at = NOW() WHERE id = $1",
                [orderId]
            );

            await client.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, $3, $4, $5)`,
                [orderId, order.status, 'ready', sellerId, 'seller']
            );

            await client.query('COMMIT');

            // Non-transactional: notifications
            try {
                await notificationService.send(
                    order.user_id, 'order',
                    'Commande prête ! 🎉',
                    `Votre commande #${orderId} est prête et en attente du livreur.`,
                    { order_id: orderId, status: 'ready' }, io
                );
            } catch (notifErr) {
                console.error('⚠️ Erreur notification (non-bloquante):', notifErr.message);
            }

            if (io) {
                io.to('deliverers').emit('order_ready_for_pickup', {
                    order_id: orderId,
                    pickup_code: pickupCode,
                    delivery_address: order.delivery_address
                });
            }

            // Réponse destinée au vendeur : sans le code de réception de l'acheteur
            const { delivery_code: _buyerCode, ...sellerView } = order;
            return { ...sellerView, status: 'ready', pickup_code: pickupCode };
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * Valide le retrait avec le pickup_code
     * Circuit A (livreur) : processing → shipped + sync delivery_orders
     * Circuit B (Pick & Go) : processing → delivered directement (pas de livreur)
     */
    async verifyPickup(orderId, code, verifierId, io = null) {
        await refundService.assertNoOpenRefund(orderId);

        const result = await pool.query(
            'SELECT * FROM orders WHERE id = $1', [orderId]
        );
        if (result.rows.length === 0) throw new Error('Commande non trouvée');
        const order = result.rows[0];

        // Contrôle d'accès : vendeur de la commande OU livreur assigné (delivery_orders)
        let isSeller = false;
        try {
            await this._getOrderForSeller(orderId, verifierId);
            isSeller = true;
        } catch (_) {
            isSeller = false;
        }
        let isAssignedDeliverer = false;
        if (!isSeller) {
            const assigned = await pool.query(
                'SELECT 1 FROM delivery_orders WHERE order_id = $1 AND deliverer_id::text = $2::text LIMIT 1',
                [orderId, String(verifierId)]
            );
            isAssignedDeliverer = assigned.rows.length > 0;
        }
        if (!isSeller && !isAssignedDeliverer) {
            throw new Error('Accès non autorisé : seul le vendeur ou le livreur assigné peut valider le pickup');
        }

        if (!['processing', 'ready'].includes(order.status)) {
            throw new Error("La commande doit être au statut 'processing' pour valider le pickup");
        }

        const isPickAndGo = order.delivery_method_id === 'pick_go';
        const typedCode = String(code || '').trim().toUpperCase();

        // PickGo : le client présente SON code (delivery_code) au guichet ; le pickup_code est
        // connu du vendeur, il ne prouverait pas que le client est venu.
        // Livreur : le vendeur lui donne le pickup_code au moment du retrait.
        const expectedCode = isPickAndGo ? order.delivery_code : order.pickup_code;
        if (!expectedCode || expectedCode !== typedCode) {
            throw new Error(isPickAndGo ? 'Code client invalide' : 'Code de pickup invalide');
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Verrou de ligne : deux validations simultanées ne créditent pas le vendeur deux fois
            const locked = await client.query('SELECT status FROM orders WHERE id = $1 FOR UPDATE', [orderId]);
            if (!['processing', 'ready'].includes(locked.rows[0]?.status)) {
                await client.query('ROLLBACK');
                throw new Error('Ce retrait a déjà été validé');
            }

            if (isPickAndGo) {
                // Circuit B — Pick & Go : directement DELIVERED
                await client.query(
                    "UPDATE orders SET status = 'delivered', delivered_at = NOW() WHERE id = $1",
                    [orderId]
                );
                await client.query(
                    `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                     VALUES ($1, $2, $3, $4, $5)`,
                    [orderId, order.status, 'delivered', verifierId, 'seller']
                );

                await client.query('COMMIT');

                // 💰 Vendeur(s) payé(s) (pas de livreur en PickGo)
                await this._settleDeliveredOrder(orderId);

                // Non-transactional: notification
                try {
                    await notificationService.send(
                        order.user_id, 'order',
                        'Commande récupérée ✅',
                        `Votre commande #${orderId} a été récupérée avec succès au guichet.`,
                        { order_id: orderId, status: 'delivered' }, io
                    );
                } catch (notifErr) {
                    console.error('⚠️ Erreur notification (non-bloquante):', notifErr.message);
                }

                return { ...order, status: 'delivered', verified_pickup: true, circuit: 'pick_go' };
            }

            // Circuit A — Livreur : ready → shipped
            await client.query(
                "UPDATE orders SET status = 'shipped', shipped_at = NOW() WHERE id = $1",
                [orderId]
            );

            // Sync delivery_orders → picked_up
            await client.query(
                "UPDATE delivery_orders SET status = 'picked_up', updated_at = NOW() WHERE order_id = $1",
                [orderId]
            );

            await client.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, $3, $4, $5)`,
                [orderId, order.status, 'shipped', verifierId, 'deliverer']
            );

            await client.query('COMMIT');

            // Non-transactional: notification
            try {
                await notificationService.send(
                    order.user_id, 'order',
                    'Colis en route ! 🚚',
                    `Votre commande #${orderId} est en cours de livraison. Votre code de réception : ${order.delivery_code}`,
                    { order_id: orderId, status: 'shipped', delivery_code: order.delivery_code }, io
                );
            } catch (notifErr) {
                console.error('⚠️ Erreur notification (non-bloquante):', notifErr.message);
            }

            return { ...order, status: 'shipped', verified_pickup: true, circuit: 'deliverer' };
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    /**
     * Valide la livraison/remise avec le delivery_code
     * Circuit A (livreur) : acheteur confirme réception (status: shipped → delivered)
     * Circuit C (Hand Delivery) : vendeur confirme remise (status: processing → delivered)
     */
    async verifyDelivery(orderId, code, userId, io = null) {
        await refundService.assertNoOpenRefund(orderId);

        // Permettre au vendeur OU à l'acheteur de vérifier
        const result = await pool.query(
            'SELECT * FROM orders WHERE id = $1', [orderId]
        );
        if (result.rows.length === 0) throw new Error('Commande non trouvée');
        const order = result.rows[0];

        const isHandDelivery = order.delivery_method_id === 'hand_delivery';
        const isBuyer = Number(order.user_id) === Number(userId);

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

        if (order.delivery_code !== String(code || '').trim().toUpperCase()) {
            throw new Error('Code de livraison invalide');
        }

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // [FIN C3] Verrou de ligne + contrôle du statut DANS la transaction :
            // deux validations simultanées ne peuvent plus créditer le vendeur deux fois.
            const locked = await client.query('SELECT status FROM orders WHERE id = $1 FOR UPDATE', [orderId]);
            if (!allowedStatuses.includes(locked.rows[0]?.status)) {
                await client.query('ROLLBACK');
                throw new Error('Cette livraison a déjà été validée');
            }

            await client.query(
                "UPDATE orders SET status = 'delivered', delivered_at = NOW() WHERE id = $1",
                [orderId]
            );

            // Sync delivery_orders → delivered (seulement si existe)
            await client.query(
                "UPDATE delivery_orders SET status = 'delivered', updated_at = NOW() WHERE order_id = $1",
                [orderId]
            );

            const previousStatus = order.status;
            const role = isBuyer ? 'buyer' : 'seller';
            await client.query(
                `INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, changed_by_role)
                 VALUES ($1, $2, $3, $4, $5)`,
                [orderId, previousStatus, 'delivered', userId, role]
            );

            await client.query('COMMIT');

            // 💰 Vendeur(s) et livreur payés, une seule fois
            await this._settleDeliveredOrder(orderId);

            // Non-transactional: notifications
            try {
                if (isBuyer) {
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
            } catch (notifErr) {
                console.error('⚠️ Erreur notification (non-bloquante):', notifErr.message);
            }

            return { ...order, status: 'delivered', verified_delivery: true, circuit: isHandDelivery ? 'hand_delivery' : 'deliverer' };
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
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
        const isBuyer = Number(order.user_id) === Number(userId);
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
            throw new Error("Impossible d'annuler cette commande : une commande payée passe par une demande de remboursement.");
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
        const deliveryMethod = order.delivery_method_id;
        const needsDeliverer = this._needsDeliverer(deliveryMethod);

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
                    estimated_time: deliveryMethod === 'oli_express' ? '45 min' : '1-2h'
                });
                console.log(`   🚚 delivery_orders créé: ID ${deliveryOrder.id} pour commande #${orderId} (mode: ${deliveryMethod}, pickup: ${pickupAddress})`);
            } catch (deliveryErr) {
                console.error('⚠️ Erreur création delivery_orders:', deliveryErr.message);
            }

            // BROADCAST POUR LIVREURS (via Socket.IO)
            if (io) {
                io.to('deliverers').emit('new_delivery_available', {
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

    /**
     * Un livreur Oli est nécessaire pour tous les modes, sauf le retrait au guichet (PickGo)
     * et la remise en main propre. Avant, maritime et moto n'avaient jamais de livreur.
     */
    _needsDeliverer(deliveryMethod) {
        return !NO_DELIVERER_MODES.includes(deliveryMethod);
    }

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

    /**
     * Commande livrée : verse le(s) vendeur(s), l'affiliation vidéo et le livreur assigné.
     * Appelée par TOUS les chemins de livraison (acheteur, livreur, PickGo, main propre) :
     * avant, la validation par le livreur ne payait pas le vendeur, et celle par
     * l'acheteur ne payait pas le livreur. Chaque versement n'a lieu qu'une fois.
     */
    async _settleDeliveredOrder(orderId) {
        try {
            await this._creditSellersForOrder(orderId);
        } catch (err) {
            console.error(`⚠️ Erreur crédit vendeur commande #${orderId}:`, err.message);
        }
        try {
            await this._creditDelivererForOrder(orderId);
        } catch (err) {
            console.error(`⚠️ Erreur crédit livreur commande #${orderId}:`, err.message);
        }
    }

    /** Verse au livreur assigné les frais de livraison (en FC, au taux figé) et les inscrit sur la course. */
    async _creditDelivererForOrder(orderId) {
        const { rows } = await pool.query(
            `SELECT d.id, d.deliverer_id, d.delivery_fee, o.exchange_rate
             FROM delivery_orders d JOIN orders o ON o.id = d.order_id
             WHERE d.order_id = $1 AND d.deliverer_id IS NOT NULL
             ORDER BY d.id DESC LIMIT 1`,
            [orderId]
        );
        const delivery = rows[0];
        if (!delivery) return null;
        const fee = orderAmountToWallet(delivery.delivery_fee || 0, delivery.exchange_rate) || 0;
        await pool.query(
            `UPDATE delivery_orders
             SET deliverer_earnings = $1, actual_delivery_time = COALESCE(actual_delivery_time, NOW())
             WHERE id = $2`,
            [fee, delivery.id]
        );
        if (fee <= 0) return null;
        return walletService.creditDeliverer(delivery.deliverer_id, fee, orderId);
    }

    /**
     * Crédite le(s) vendeur(s) pour une commande livrée
     * Calcule le montant par vendeur et crédite 100%
     */
    async _creditSellersForOrder(orderId) {
        const itemsResult = await pool.query(
            `SELECT p.seller_id, oi.product_price, oi.quantity, oi.origin_video_id, vs.user_id AS video_creator_id,
                    o.exchange_rate
             FROM order_items oi
             JOIN orders o ON o.id = oi.order_id
             JOIN products p ON oi.product_id::integer = p.id
             LEFT JOIN video_sales vs ON oi.origin_video_id = vs.id
             WHERE oi.order_id = $1 AND p.seller_id IS NOT NULL`,
            [orderId]
        );

        if (itemsResult.rows.length === 0) {
            console.log(`   ⚠️ Aucun item vendeur trouvé pour commande #${orderId}`);
            return;
        }

        const exchangeRate = itemsResult.rows[0].exchange_rate;
        const sellerTotals = {};
        const videoCreatorTotals = {};

        for (const row of itemsResult.rows) {
            const sellerId = row.seller_id;
            const itemTotal = parseFloat(row.product_price) * parseInt(row.quantity);
            
            let sellerAmount = itemTotal;
            
            // Commission affiliation vidéo (2%)
            if (row.origin_video_id && row.video_creator_id) {
                const creatorId = row.video_creator_id;
                // Ne pas payer la commission si le créateur de la vidéo est le vendeur lui-même
                if (creatorId != sellerId) {
                    const commission = itemTotal * 0.02;
                    sellerAmount -= commission; // Déduit du vendeur
                    
                    if (!videoCreatorTotals[creatorId]) videoCreatorTotals[creatorId] = 0;
                    videoCreatorTotals[creatorId] += commission;
                }
            }

            if (!sellerTotals[sellerId]) sellerTotals[sellerId] = 0;
            sellerTotals[sellerId] += sellerAmount;
        }

        // Payer les vendeurs
        for (const [sellerId, usdAmount] of Object.entries(sellerTotals)) {
            const amount = orderAmountToWallet(usdAmount, exchangeRate);
            if (amount <= 0) continue;
            try {
                await walletService.creditSeller(sellerId, amount, orderId);
            } catch (err) {
                console.error(`⚠️ Erreur crédit vendeur #${sellerId} pour commande #${orderId}:`, err.message);
            }
        }

        // Payer les créateurs de vidéos (Affiliation 2%)
        for (const [creatorId, usdAmount] of Object.entries(videoCreatorTotals)) {
            const amount = orderAmountToWallet(usdAmount, exchangeRate);
            if (amount <= 0) continue;
            try {
                const walletRepository = require('../repositories/wallet.repository');
                await walletRepository.performDeposit(creatorId, amount, {
                    type: 'reward',
                    provider: 'LIVE_SHOPPING',
                    reference: `AFFILIATION_${orderId}_${creatorId}_${Date.now()}`,
                    description: `Commission d'affiliation vidéo (2%) sur la commande #${orderId}`
                });
            } catch (err) {
                console.error(`⚠️ Erreur crédit affiliation vidéo #${creatorId} pour commande #${orderId}:`, err.message);
            }
        }
    }
}

module.exports = new OrderService();
