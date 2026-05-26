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

// 🏦 OLI Bank — import différé pour éviter les dépendances circulaires
let _oliBank = null;
function getOliBank() {
    if (!_oliBank) _oliBank = require('./oli_bank.service');
    return _oliBank;
}

/**
 * Fire-and-forget : enregistre la transaction dans le Grand Livre OLI Bank.
 * Ne bloque jamais le flux principal du wallet.
 */
function _recordToLedger(userId, txType, amount, meta = {}) {
    setImmediate(async () => {
        try {
            const bank = getOliBank();
            // S'assurer que le portail de l'utilisateur existe
            await bank.initializeUserPortal(userId);
            await bank.recordLedgerEntry(userId, txType, amount, meta);
        } catch (err) {
            console.warn(`⚠️ OLI Bank ledger non-bloquant [${txType}] user#${userId}:`, err.message);
        }
    });
}

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
    // 0. Système - Banque OLI (Frais)
    // ─────────────────────────────────────────────────────────────

    /**
     * Crédite le wallet système (user 0) avec les frais collectés.
     */
    async _creditSystemWallet(amount, reference, description) {
        if (amount <= 0) return;
        
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            
            // Assurer que le user 0 existe
            await client.query(`
                INSERT INTO users (id, name, email, phone, role, password, wallet)
                VALUES (0, 'Banque Crédit OLI', 'bank@oli-core.com', '+0000000000', 'admin', 'N/A', 0)
                ON CONFLICT (id) DO NOTHING
            `);
            
            // Obtenir le wallet système (le créera si inexistant)
            const sysWallet = await walletRepository._getOrCreateWallet(0, client);
            const newBalance = parseFloat(sysWallet.balance) + amount;
            
            await client.query(`UPDATE wallets SET balance = $1 WHERE id = $2`, [newBalance, sysWallet.id]);
            await client.query(`UPDATE users SET wallet = $1 WHERE id = 0`, [newBalance]);
            
            await walletRepository._insertTx(client, {
                walletId: sysWallet.id,
                userId: 0,
                type: 'credit',
                amount: amount,
                balanceAfter: newBalance,
                provider: 'SYSTEM_FEE',
                reference,
                description,
            });
            
            await client.query('COMMIT');
            console.log(`🏦 Banque OLI Créditée : +$${amount.toFixed(2)} (${description})`);
        } catch (err) {
            await client.query('ROLLBACK');
            console.error('Erreur _creditSystemWallet :', err.message);
        } finally {
            client.release();
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Recharge — Mobile Money
    // ─────────────────────────────────────────────────────────────

    async deposit(userId, amountRaw, provider, phoneNumber) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!provider) throw new Error('Opérateur Mobile Money requis');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // Application des frais OLI (5%) - Le client paie 105% via Unipesa
        const feeAmount = amount * 0.05;
        const totalToCharge = amount + feeAmount;

        const reference = `DEP_${userId}_${Date.now()}`;

        // Appel API Unipesa C2B - Mobile Money avec le montant total (Montant + Frais)
        const unipesaRes = await unipesaService.depositC2B({
            amount: totalToCharge,
            currency: 'USD',
            provider,
            phoneNumber,
            reference,
            customer_user_id: String(userId)
        });

        if (!unipesaRes.success || unipesaRes.status === 'failed') {
            throw new Error(unipesaRes.message || 'Échec de l\'initiation du dépôt');
        }

        // On enregistre le montant net que l'utilisateur recevra en attente. 
        // Les frais seront prélevés lors de la confirmation du webhook.
        const depResult = await walletRepository.performDeposit(userId, 0, {
            type: 'deposit_pending',
            provider: 'UNIPESA',
            reference: unipesaRes.transaction_id || reference,
            description: `Recharge initiée via ${provider}. En attente de validation PIN.`,
            metadata: { netAmount: amount, feeAmount: feeAmount }
        });
        // 🏦 OLI Bank — Ledger (non-bloquant)
        _recordToLedger(userId, 'deposit', amount, { reference, provider, fee: feeAmount });
        return depResult;
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

        // Frais de retrait (5%)
        const feeAmount = amount * 0.05;
        const totalToDeduct = amount + feeAmount;

        // Vérification solde OLI (doit couvrir le montant + les frais)
        const balance = await walletRepository.getBalance(userId);
        if (balance < totalToDeduct) {
            throw new Error(`Solde insuffisant (disponible: $${balance.toFixed(2)}, requis: $${totalToDeduct.toFixed(2)} incluant 5% de frais)`);
        }

        const reference = `WD_${userId}_${Date.now()}`;

        // IMPORTANT : Débit immédiat du Wallet OLI (Montant Total = Retrait + Frais) pour empêcher le double retrait
        const withdrawResult = await walletRepository.performWithdrawal(userId, totalToDeduct, {
            type: 'withdrawal_pending',
            provider: 'UNIPESA',
            reference,
            description: `Retrait vers ${provider} ($${amount.toFixed(2)} + $${feeAmount.toFixed(2)} frais)`,
            metadata: { netAmount: amount, feeAmount: feeAmount }
        });

        // Appel API Unipesa B2C (Décaissements) - Unipesa envoie uniquement le montant NET
        const unipesaRes = await unipesaService.withdrawB2C({
            amount,
            currency: 'USD',
            provider,
            phoneNumber,
            reference,
            customer_user_id: String(userId)
        });

        if (!unipesaRes.success || unipesaRes.status === 'failed') {
             // Si l'API échoue *immédiatement*, on rembourse le wallet (Montant + Frais)
             await walletRepository.performDeposit(userId, totalToDeduct, {
                type: 'refund',
                provider: 'UNIPESA',
                reference: `${reference}_REFUND`,
                description: `Échec du retrait Unipesa - Remboursé`,
             });
             throw new Error(unipesaRes.message || "Impossible d'initier le décaissement externe");
        }

        // Le retrait a réussi au niveau de l'initiation. On crédite la Banque OLI avec les 5% de frais.
        await this._creditSystemWallet(feeAmount, `${reference}_FEE`, `Frais 5% sur retrait de $${amount.toFixed(2)} (User #${userId})`);
        // 🏦 OLI Bank — Ledger (non-bloquant)
        _recordToLedger(userId, 'withdrawal', amount, { reference, provider, fee: feeAmount });

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

        const payResult = await walletRepository.performWithdrawal(userId, amount, {
            type: 'payment',
            provider: 'WALLET',
            reference: `ORDER_${orderId || Date.now()}`,
            description: `Paiement commande${orderId ? ` #${orderId}` : ''}`,
            orderId,
        });
        // 🏦 OLI Bank — Ledger escrow_lock (non-bloquant)
        _recordToLedger(userId, 'escrow_lock', amount, { orderId, reference: `ORDER_${orderId}` });
        return payResult;
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
        // 🏦 OLI Bank — Ledger escrow_release (non-bloquant)
        _recordToLedger(sellerId, 'escrow_release', amount, { orderId, role: 'seller' });
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
