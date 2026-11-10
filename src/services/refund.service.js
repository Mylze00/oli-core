/**
 * Demandes de remboursement des commandes payées.
 *
 * Le client ouvre un dossier (table disputes, type 'refund_request') et la commande
 * reste bloquée pendant l'examen. Seul un administrateur décide du remboursement.
 */
const pool = require('../config/db');
const walletRepository = require('../repositories/wallet.repository');
const notificationService = require('./notification.service');
const exchangeRateService = require('./exchange-rate.service');
const { orderAmountToWallet } = require('../utils/order-currency');

const REFUND_REQUEST = 'refund_request';
const STATUSES_BEFORE_SHIPPING = ['paid', 'processing', 'ready'];
const PHASE_BEFORE_SHIPPING = 'before_shipping';
const PHASE_AFTER_DELIVERY = 'after_delivery';
const MAX_REASON_LENGTH = 500;

function refundError(status, message) {
    const error = new Error(message);
    error.status = status;
    return error;
}

function frozenOrderError() {
    return refundError(409, "Une demande de remboursement est en cours d'examen : cette commande est bloquée.");
}

class RefundService {
    /** Indique si l'administrateur peut accepter un remboursement à ce stade de la commande. */
    canRefundStatus(orderStatus) {
        return STATUSES_BEFORE_SHIPPING.includes(orderStatus);
    }

    /** @throws {Error} 409 si la commande attend la décision d'un administrateur */
    async assertNoOpenRefund(orderId) {
        const result = await pool.query(
            `SELECT 1 FROM disputes
             WHERE order_id = $1 AND type = $2 AND status = 'open'
             LIMIT 1`,
            [orderId, REFUND_REQUEST]
        );
        if (result.rows.length > 0) {
            throw frozenOrderError();
        }
    }

    /** @throws {Error} 409 si la commande de cette livraison attend une décision */
    async assertDeliveryNotFrozen(deliveryId) {
        const result = await pool.query(
            `SELECT 1 FROM disputes d
             JOIN delivery_orders delivery ON delivery.order_id = d.order_id
             WHERE delivery.id = $1 AND d.type = $2 AND d.status = 'open'
             LIMIT 1`,
            [deliveryId, REFUND_REQUEST]
        );
        if (result.rows.length > 0) {
            throw frozenOrderError();
        }
    }

    /**
     * Ouvre un dossier de remboursement pour l'acheteur.
     * Une seule demande est possible avant l'expédition, et une seule après la livraison.
     */
    async requestRefund(userId, orderId, rawReason, rawDescription, io = null) {
        const reason = typeof rawReason === 'string' ? rawReason.trim() : '';
        if (!reason || reason.length > MAX_REASON_LENGTH) {
            throw refundError(400, `Indiquez le motif de votre demande (${MAX_REASON_LENGTH} caractères maximum).`);
        }
        const description = typeof rawDescription === 'string' ? rawDescription.trim() || null : null;

        const orderResult = await pool.query(
            'SELECT id, status, seller_id FROM orders WHERE id = $1 AND user_id = $2',
            [orderId, userId]
        );
        const order = orderResult.rows[0];
        if (!order) {
            throw refundError(404, 'Commande non trouvée');
        }

        let phase;
        if (STATUSES_BEFORE_SHIPPING.includes(order.status)) {
            phase = PHASE_BEFORE_SHIPPING;
        } else if (order.status === 'delivered') {
            phase = PHASE_AFTER_DELIVERY;
        } else {
            throw refundError(400, "Le remboursement n'est pas disponible pour cette commande à ce stade.");
        }

        const inserted = await pool.query(
            `INSERT INTO disputes (order_id, reporter_id, target_id, reason, description, type, request_phase)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (order_id, request_phase) WHERE type = 'refund_request' DO NOTHING
             RETURNING *`,
            [orderId, userId, order.seller_id, reason, description, REFUND_REQUEST, phase]
        );
        if (inserted.rows.length === 0) {
            throw refundError(409, 'Une demande de remboursement a déjà été traitée ou est en cours pour cette commande.');
        }

        await this._notify(order.seller_id, 'Demande de remboursement',
            `Le client a demandé le remboursement de la commande #${orderId}. Elle est bloquée pendant l'examen.`,
            orderId, io);

        return inserted.rows[0];
    }

    /**
     * Enregistre la décision de l'administrateur et rembourse si elle est acceptée.
     * Le dossier reste verrouillé jusqu'à la fin : deux décisions simultanées
     * ne peuvent pas produire deux remboursements.
     */
    async decide(disputeId, adminId, accepted, notes, io = null) {
        const client = await pool.connect();
        let dispute;
        let refundAmount = null;

        try {
            await client.query('BEGIN');

            const found = await client.query(
                `SELECT d.id, d.status, d.type, d.order_id,
                        o.user_id AS buyer_id, o.seller_id, o.status AS order_status,
                        o.total_amount, o.exchange_rate, o.payment_method
                 FROM disputes d
                 JOIN orders o ON o.id = d.order_id
                 WHERE d.id = $1
                 FOR UPDATE OF d, o`,
                [disputeId]
            );
            dispute = found.rows[0];
            if (!dispute || dispute.type !== REFUND_REQUEST) {
                throw refundError(404, 'Demande de remboursement non trouvée');
            }
            if (dispute.status !== 'open') {
                throw refundError(409, 'Cette demande a déjà été traitée.');
            }

            if (accepted) {
                if (dispute.order_status === 'delivered') {
                    throw refundError(409, "Le remboursement après livraison n'est pas encore disponible : le vendeur a déjà été payé.");
                }
                if (!this.canRefundStatus(dispute.order_status)) {
                    throw refundError(409, "Cette commande ne peut plus être remboursée à ce stade.");
                }
                refundAmount = await this._computeRefundAmount(dispute);

                // La contrainte sur le statut est vérifiée avant de créditer le portefeuille
                await client.query(
                    `UPDATE orders SET status = 'refunded', updated_at = NOW() WHERE id = $1`,
                    [dispute.order_id]
                );
                await client.query(
                    `UPDATE delivery_orders SET status = 'cancelled', updated_at = NOW()
                     WHERE order_id = $1 AND status NOT IN ('delivered', 'cancelled')`,
                    [dispute.order_id]
                );
                await this._creditBuyerOnce(client, dispute, refundAmount);
            }

            await client.query(
                `UPDATE disputes
                 SET status = $1, resolution_notes = $2, resolved_by = $3, resolved_at = NOW(),
                     refund_amount_fc = $4, updated_at = NOW()
                 WHERE id = $5`,
                [accepted ? 'resolved' : 'rejected', notes || null, adminId, refundAmount, disputeId]
            );

            await client.query('COMMIT');
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }

        await this._notifyDecision(dispute, accepted, refundAmount, io);
        return { accepted, refundAmount };
    }

    /**
     * Montant à rendre en FC. Une ancienne commande payée au portefeuille a été débitée
     * sans conversion ; une ancienne commande payée autrement est convertie au taux du jour.
     */
    async _computeRefundAmount(order) {
        if (order.exchange_rate || order.payment_method === 'wallet') {
            return orderAmountToWallet(order.total_amount, order.exchange_rate);
        }
        try {
            return orderAmountToWallet(order.total_amount, await exchangeRateService.getRateForOrder());
        } catch (error) {
            console.error('❌ Remboursement impossible, taux indisponible:', error.message);
            throw refundError(503, 'Le taux de change est momentanément indisponible. Réessayez dans quelques instants.');
        }
    }

    /** Ne crédite pas deux fois si une validation précédente a échoué après le dépôt. */
    async _creditBuyerOnce(client, dispute, amount) {
        const reference = `REFUND_ORDER_${dispute.order_id}`;
        const existing = await client.query(
            'SELECT 1 FROM wallet_transactions WHERE reference = $1 LIMIT 1',
            [reference]
        );
        if (existing.rows.length > 0) return;

        await walletRepository.performDeposit(dispute.buyer_id, amount, {
            type: 'refund',
            provider: 'OLI_PLATFORM',
            reference,
            description: `Remboursement de la commande #${dispute.order_id}`,
            orderId: dispute.order_id,
        });
    }

    async _notifyDecision(dispute, accepted, refundAmount, io) {
        const orderId = dispute.order_id;
        const buyerMessage = accepted
            ? `Votre commande #${orderId} a été remboursée : ${refundAmount} FC crédités sur votre portefeuille.`
            : `Votre demande de remboursement pour la commande #${orderId} a été refusée.`;
        const sellerMessage = accepted
            ? `La commande #${orderId} a été remboursée au client et annulée.`
            : `La demande de remboursement de la commande #${orderId} a été refusée. La commande peut reprendre.`;

        await this._notify(dispute.buyer_id, 'Décision de remboursement', buyerMessage, orderId, io);
        await this._notify(dispute.seller_id, 'Décision de remboursement', sellerMessage, orderId, io);
    }

    /** Une notification en échec ne doit pas remettre en cause la décision. */
    async _notify(userId, title, body, orderId, io) {
        if (!userId) return;
        try {
            await notificationService.send(userId, 'order', title, body, { order_id: orderId }, io);
        } catch (error) {
            console.error('⚠️ Notification de remboursement non envoyée:', error.message);
        }
    }
}

module.exports = new RefundService();
