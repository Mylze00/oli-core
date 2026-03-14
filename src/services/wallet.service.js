/**
 * Wallet Service OLI — Logique métier du portefeuille
 *
 * Flux supportés :
 *  1. Recharge via Mobile Money (deposit)
 *  2. Recharge via Carte bancaire (depositByCard)
 *  3. Retrait vers Mobile Money (withdraw)
 *  4. Paiement de commande (payOrder)
 *  5. Réception fonds — vendeur (creditSeller)
 *  6. Réception fonds — livreur (creditDeliverer)
 *  7. Transfert P2P — envoi cash (transferToUser)
 *  8. Récompense points (rewardUser)
 */
const walletRepository = require('../repositories/wallet.repository');
const unipesaService = require('./unipesa.service');
const pool = require('../config/db');


// Taux FC→USD fixe (à externaliser dans exchange_rates si nécessaire)
const FC_TO_USD = 2800;

class WalletService {

    // ─────────────────────────────────────────────────────────────
    // Lecture
    // ─────────────────────────────────────────────────────────────

    async getBalance(userId) {
        return await walletRepository.getBalance(userId);
    }

    async getHistory(userId, limit = 30) {
        return await walletRepository.getHistory(userId, limit);
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Recharge — Mobile Money
    // ─────────────────────────────────────────────────────────────

    async deposit(userId, amountRaw, provider, phoneNumber) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!provider) throw new Error('Opérateur Mobile Money requis');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // Résoudre l'ID fournisseur Unipesa à partir du nom de l'opérateur
        const reference = `DEP_${userId}_${Date.now()}`;

        // Appel API Unipesa C2B - Mobile Money
        const unipesaRes = await unipesaService.depositC2B({
            amount,
            currency: 'USD',
            provider,
            phoneNumber,
            reference,
            customer_user_id: String(userId)
        });

        if (!unipesaRes.success || unipesaRes.status === 'failed') {
            throw new Error(unipesaRes.message || 'Échec de l\'initiation du dépôt');
        }

        // Enregistrement en attente — le solde sera crédité par le webhook /webhooks/unipesa/deposit
        return await walletRepository.performDeposit(userId, 0, {
            type: 'deposit_pending',
            provider: 'UNIPESA',
            reference: unipesaRes.transaction_id || reference,
            description: `Recharge initiée via ${provider}. En attente de validation PIN.`,
        });
    }

    // ─────────────────────────────────────────────────────────────
    // 2. Recharge — Carte bancaire
    // ─────────────────────────────────────────────────────────────

    async depositByCard(userId, amountRaw, cardInfo) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        this._validateCard(cardInfo);

        const reference = `CARD_${userId}_${Date.now()}`;

        // Appel API Unipesa C2B - Carte Bancaire (provider = equity ou ecobank selon la carte)
        const unipesaRes = await unipesaService.depositC2B({
            amount,
            currency: 'USD',
            provider: 'card', // mappage vers equity (ID 20) par défaut
            phoneNumber: '+243000000000',
            reference,
            customer_user_id: String(userId)
        });

        if (!unipesaRes.success) {
            throw new Error(unipesaRes.message || 'Échec de l\'initiation du paiement carte');
        }

        // Solde en attente — sera crédité par le webhook /webhooks/unipesa/deposit
        return await walletRepository.performDeposit(userId, 0, {
            type: 'deposit_pending',
            provider: 'UNIPESA',
            reference: unipesaRes.transaction_id || reference,
            description: `Recharge carte ****${cardNumber.slice(-4)} en attente`,
        });
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Retrait — vers Mobile Money
    // ─────────────────────────────────────────────────────────────

    async withdraw(userId, amountRaw, provider, phoneNumber) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!provider) throw new Error('Opérateur requis');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // Vérification solde OLI
        const balance = await walletRepository.getBalance(userId);
        if (balance < amount) {
            throw new Error(`Solde insuffisant (${balance.toFixed(2)} USD disponible)`);
        }

        const reference = `WD_${userId}_${Date.now()}`;

        // IMPORTANT : Débit immédiat du Wallet OLI pour empêcher le double retrait
        const withdrawResult = await walletRepository.performWithdrawal(userId, amount, {
            type: 'withdrawal_pending',
            provider: 'UNIPESA',
            reference,
            description: `Retrait vers ${provider} (${phoneNumber}) initié`,
        });

        // Appel API Unipesa B2C (Décaissements)
        const unipesaRes = await unipesaService.withdrawB2C({
            amount,
            currency: 'USD',
            provider,
            phoneNumber,
            reference,
            customer_user_id: String(userId)
        });

        if (!unipesaRes.success || unipesaRes.status === 'failed') {
             // Si l'API échoue *immédiatement*, on rembourse le wallet
             await walletRepository.performDeposit(userId, amount, {
                type: 'refund',
                provider: 'UNIPESA',
                reference: `${reference}_REFUND`,
                description: `Échec du retrait Unipesa - Remboursé`,
             });
             throw new Error(unipesaRes.message || "Impossible d'initier le décaissement externe");
        }

        // Succès d'initiation : le webhook /webhooks/unipesa/withdrawal confirmera ou remboursera.
        return withdrawResult;
    }

    // ─────────────────────────────────────────────────────────────
    // 4. Paiement de commande via Wallet
    // ─────────────────────────────────────────────────────────────

    /**
     * Débite le wallet de l'acheteur pour une commande.
     * Lève une erreur claire si solde insuffisant.
     */
    async payOrder(userId, amountRaw, orderId = null) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant de commande invalide');

        return await walletRepository.performWithdrawal(userId, amount, {
            type: 'payment',
            provider: 'WALLET',
            reference: `ORDER_${orderId || Date.now()}`,
            description: `Paiement commande${orderId ? ` #${orderId}` : ''}`,
            orderId,
        });
    }

    // ─────────────────────────────────────────────────────────────
    // 5. Réception fonds — Vendeur
    // ─────────────────────────────────────────────────────────────

    /**
     * Crédite le wallet du vendeur après livraison confirmée.
     * Appelé UNE SEULE fois depuis verifyPickup (Pick&Go) ou verifyDelivery.
     */
    async creditSeller(sellerId, amountRaw, orderId) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) {
            console.warn(`⚠️ creditSeller: montant nul pour commande #${orderId}, ignoré`);
            return null;
        }

        const result = await walletRepository.performDeposit(sellerId, amount, {
            type: 'credit',
            provider: 'OLI_PLATFORM',
            reference: `SALE_ORDER_${orderId}`,
            description: `Vente confirmée — commande #${orderId}`,
            orderId,
        });

        console.log(`💰 Vendeur #${sellerId} crédité : +${amount.toFixed(2)} USD (commande #${orderId}) → solde: ${result.balanceAfter.toFixed(2)} USD`);
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // 6. Réception fonds — Livreur
    // ─────────────────────────────────────────────────────────────

    /**
     * Crédite le wallet du livreur après livraison confirmée.
     */
    async creditDeliverer(delivererId, amountRaw, orderId) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) {
            console.warn(`⚠️ creditDeliverer: montant nul pour commande #${orderId}, ignoré`);
            return null;
        }

        const result = await walletRepository.performDeposit(delivererId, amount, {
            type: 'credit',
            provider: 'OLI_PLATFORM',
            reference: `DELIVERY_ORDER_${orderId}`,
            description: `Commission livraison — commande #${orderId}`,
            orderId,
        });

        console.log(`🚚💰 Livreur #${delivererId} crédité : +${amount.toFixed(2)} USD (commande #${orderId}) → solde: ${result.balanceAfter.toFixed(2)} USD`);
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // 7. Transfert P2P — Envoi cash entre utilisateurs
    // ─────────────────────────────────────────────────────────────

    /**
     * Transfère de l'argent d'un utilisateur à un autre.
     * Supporte USD et FC (Francs Congolais).
     * Atomique : si le crédit échoue, le débit est annulé.
     */
    async transferToUser(senderIdRaw, receiverIdRaw, amountRaw, currency = 'USD') {
        const senderId = parseInt(senderIdRaw);
        const receiverId = parseInt(receiverIdRaw);
        let amount = parseFloat(amountRaw);

        if (!senderId) throw new Error('Expéditeur invalide');
        if (!receiverId) throw new Error('Destinataire invalide');
        if (senderId === receiverId) throw new Error("Impossible de s'envoyer de l'argent à soi-même");
        if (!amount || amount <= 0) throw new Error('Montant invalide');

        // Conversion FC → USD
        if (currency === 'FC') {
            amount = amount / FC_TO_USD;
        }
        if (amount < 0.01) throw new Error('Montant trop faible après conversion');

        const reference = `P2P_${Date.now()}_${senderId}_${receiverId}`;

        // Exécuter les deux opérations dans une seule transaction PostgreSQL
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // — Débit expéditeur (vérifie le solde atomiquement)
            const senderWallet = await walletRepository._getOrCreateWallet(senderId, client);
            if (senderWallet.is_frozen) throw new Error('Votre wallet est gelé');
            const senderBalance = parseFloat(senderWallet.balance);
            if (senderBalance < amount) {
                throw new Error(`Solde insuffisant (${senderBalance.toFixed(2)} USD disponible)`);
            }
            const newSenderBalance = senderBalance - amount;
            await client.query(`UPDATE wallets SET balance = $1 WHERE id = $2`, [newSenderBalance, senderWallet.id]);
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newSenderBalance, senderId]);
            await walletRepository._insertTx(client, {
                walletId: senderWallet.id, userId: senderId, type: 'transfer',
                amount: -amount, balanceAfter: newSenderBalance,
                provider: 'P2P', reference,
                description: `Envoi à utilisateur #${receiverId}`,
            });

            // — Crédit destinataire
            const receiverWallet = await walletRepository._getOrCreateWallet(receiverId, client);
            if (receiverWallet.is_frozen) throw new Error('Le destinataire ne peut pas recevoir de fonds');
            const newReceiverBalance = parseFloat(receiverWallet.balance) + amount;
            await client.query(`UPDATE wallets SET balance = $1 WHERE id = $2`, [newReceiverBalance, receiverWallet.id]);
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newReceiverBalance, receiverId]);
            await walletRepository._insertTx(client, {
                walletId: receiverWallet.id, userId: receiverId, type: 'transfer',
                amount, balanceAfter: newReceiverBalance,
                provider: 'P2P', reference,
                description: `Reçu de utilisateur #${senderId}`,
            });

            await client.query('COMMIT');

            console.log(`💸 Transfert P2P: #${senderId} → #${receiverId} — ${amount.toFixed(2)} USD (${amountRaw} ${currency})`);

            return {
                success: true,
                amountUSD: amount,
                amountOriginal: parseFloat(amountRaw),
                currency,
                reference,
                senderNewBalance: newSenderBalance,
                receiverNewBalance: newReceiverBalance,
            };

        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 8. Récompense utilisateur (reward points → wallet)
    // ─────────────────────────────────────────────────────────────

    /**
     * Crédite des points de récompense.
     * 100 points = 1 USD (convertis automatiquement si > 100).
     */
    async rewardUser(userId, points, reason = 'Récompense OLI') {
        const pointsInt = Math.floor(parseInt(points) || 0);
        if (pointsInt <= 0) return null;

        // Ajouter les points dans users.reward_points
        await pool.query(
            `UPDATE users SET reward_points = COALESCE(reward_points, 0) + $1 WHERE id = $2`,
            [pointsInt, parseInt(userId)]
        );

        // Si >= 100 points → convertir en USD et créditer le wallet
        const usdAmount = Math.floor(pointsInt / 100);
        if (usdAmount > 0) {
            const usedPoints = usdAmount * 100;

            // Déduire les points convertis
            await pool.query(
                `UPDATE users SET reward_points = GREATEST(0, reward_points - $1) WHERE id = $2`,
                [usedPoints, parseInt(userId)]
            );

            await walletRepository.performDeposit(userId, usdAmount, {
                type: 'reward',
                provider: 'OLI_REWARDS',
                reference: `REWARD_${Date.now()}`,
                description: `Conversion ${usedPoints} points → ${usdAmount} USD (${reason})`,
            });

            console.log(`🎁 User #${userId}: +${pointsInt} points → +${usdAmount} USD crédités`);
            return { pointsAdded: pointsInt, usdConverted: usdAmount };
        }

        console.log(`🎁 User #${userId}: +${pointsInt} points ajoutés (pas encore convertis)`);
        return { pointsAdded: pointsInt, usdConverted: 0 };
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers privés
    // ─────────────────────────────────────────────────────────────

    _validateCard(cardInfo) {
        if (!cardInfo?.cardNumber || !cardInfo?.expiryDate || !cardInfo?.cvv) {
            throw new Error('Informations de carte incomplètes (cardNumber, expiryDate, cvv requis)');
        }
        const num = cardInfo.cardNumber.replace(/\s/g, '');
        if (!/^\d{16}$/.test(num)) throw new Error('Numéro de carte invalide (16 chiffres)');
        if (!/^\d{3,4}$/.test(cardInfo.cvv)) throw new Error('CVV invalide (3 ou 4 chiffres)');
        if (!/^\d{2}\/\d{2}$/.test(cardInfo.expiryDate)) throw new Error("Date d'expiration invalide (MM/YY)");
    }
}

module.exports = new WalletService();
