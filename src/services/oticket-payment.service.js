const pool = require('../config/db');
const crypto = require('crypto');

class OticketPaymentService {
    
    /**
     * Webhook appelé par la passerelle de paiement (ex: Mobile Money)
     */
    async processPaymentWebhook(payload) {
        const { orderId, amountPaid, transactionId, status } = payload;

        if (status !== 'SUCCESS') {
            // Gérer le cas d'échec
            return;
        }

        const client = await pool.connect();
        
        try {
            await client.query('BEGIN');

            // 1. Verrouiller la commande pour éviter les doubles paiements (Pessimistic Locking)
            const orderRes = await client.query(
                `SELECT * FROM orders WHERE id = $1 FOR UPDATE`, 
                [orderId]
            );

            if (orderRes.rows.length === 0) throw new Error("Commande introuvable");
            const order = orderRes.rows[0];

            if (order.payment_status === 'completed') {
                throw new Error("Cette commande a déjà été payée.");
            }

            // 2. Valider le montant reçu
            if (parseFloat(amountPaid) < parseFloat(order.total_amount)) {
                throw new Error("Le montant payé est inférieur au total attendu.");
            }

            // 3. Mettre à jour la commande principale
            await client.query(
                `UPDATE orders 
                 SET payment_status = 'completed', 
                     status = 'paid',
                     gateway_transaction_id = $2,
                     updated_at = NOW() 
                 WHERE id = $1`,
                [orderId, transactionId]
            );

            // 4. Récupérer les items de la commande pour la ventilation
            const itemsRes = await client.query(
                `SELECT oi.*, p.seller_id as organizer_id 
                 FROM order_items oi
                 JOIN products p ON oi.product_id::integer = p.id
                 WHERE oi.order_id = $1`, 
                [orderId]
            );

            // 5. Créditer l'organisateur et mettre à jour les prix des items
            for (const item of itemsRes.rows) {
                // Pour Oticket, le product_price stocké dans la DB est le P_total (P_base * 1.08)
                // Donc P_base = P_total / 1.08
                const finalPrice = parseFloat(item.product_price);
                const basePrice = finalPrice / 1.08;
                const platformFee = finalPrice - basePrice;

                // Mise à jour de la ventilation dans order_items
                await client.query(
                    `UPDATE order_items 
                     SET base_price = $1, platform_fee = $2, final_price = $3 
                     WHERE id = $4`,
                    [basePrice.toFixed(2), platformFee.toFixed(2), finalPrice.toFixed(2), item.id]
                );

                // Créditer l'organisateur (P_base)
                // On utilise INSERT ... ON CONFLICT pour initialiser le solde s'il n'existe pas
                await client.query(
                    `INSERT INTO organizer_balances (organizer_id, available_balance, total_earned)
                     VALUES ($1, $2, $2)
                     ON CONFLICT (organizer_id) 
                     DO UPDATE SET 
                        available_balance = organizer_balances.available_balance + $2,
                        total_earned = organizer_balances.total_earned + $2,
                        updated_at = NOW()`,
                    [item.organizer_id, basePrice.toFixed(2)]
                );

                // 6. Génération du Billet (QR Code unique)
                const ticketCode = crypto.randomBytes(8).toString('hex').toUpperCase();
                // Assumant une table tickets si elle existe plus tard
                // await client.query(\`INSERT INTO tickets (order_item_id, ticket_code) VALUES ($1, $2)\`, [item.id, ticketCode]);
            }

            await client.query('COMMIT');
            return { success: true, message: 'Paiement traité et ventilé avec succès' };

        } catch (error) {
            await client.query('ROLLBACK');
            console.error("❌ Erreur Webhook Oticket:", error.message);
            throw error;
        } finally {
            client.release();
        }
    }
}

module.exports = new OticketPaymentService();
