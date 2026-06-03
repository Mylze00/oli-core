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
const { FEES, FC_TO_USD_FALLBACK } = require('../config/index'); // [P1.4]

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

// [P1.4] Taux FC→USD depuis la configuration centralisée (plus de hardcode)
const FC_TO_USD = FC_TO_USD_FALLBACK; // config/index.js → FC_TO_USD_FALLBACK

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
                INSERT INTO users (id, name, phone, wallet)
                VALUES (0, 'Banque Crédit OLI', '+0000000000', 0)
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

    async deposit(userId, amountFC, provider, phoneNumber) {
        // amountFC : montant brut en Francs Congolais saisi par l'utilisateur
        const amount = parseFloat(amountFC);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // ⚠️  NE PAS multiplier par FC_TO_USD ici — amount est déjà en FC
        //     La conversion USD→FC avait été introduite par erreur (multipliait par 2800 !)

        // ── [FIX B1] : Appel de la vraie méthode initiateDeposit (C2B) ────
        // unipesa.service gère lui-même les 6% de frais (3% Unipesa + 3% OLI).
        // L'utilisateur saisit le montant BRUT qu'il envoie depuis son téléphone.
        const unipesaRes = await unipesaService.initiateDeposit(
            userId,
            phoneNumber,
            amount // montant brut en FC — les frais sont déduits dans unipesa.service
        );

        // L'opération est en cours sur le téléphone de l'utilisateur (push USSD).
        // Le crédit du wallet se fera à la réception du webhook de confirmation.
        // 🏦 OLI Bank — Ledger non-bloquant (montant net estimé)
        _recordToLedger(userId, 'deposit', unipesaRes.netAmountFC, {
            reference: unipesaRes.oliOrderId,
            provider: provider || unipesaRes.provider,
            fee: unipesaRes.totalFeeFC,
        });

        return {
            status:          'pending',
            oliOrderId:      unipesaRes.oliOrderId,
            amountFC:        unipesaRes.amountFC,
            netAmountFC:     unipesaRes.netAmountFC,
            totalFeeFC:      unipesaRes.totalFeeFC,
            aggregatorFeeFC: unipesaRes.aggregatorFeeFC,
            oliFeeFC:        unipesaRes.oliFeeFC,
            provider:        unipesaRes.provider,
            phone:           phoneNumber,
            message:         'Paiement initié. Validez sur votre téléphone Mobile Money.',
        };
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
        // [FIX B5] : cardNumber doit être lu depuis cardInfo.cardNumber
        const last4 = cardInfo.cardNumber.replace(/\s/g, '').slice(-4);

        // Note: Unipesa ne supporte pas directement le paiement par carte bancaire
        // via C2B standard. Ce flux doit passer par un gateway spécifique (Equity/Ecobank).
        // Pour l'instant on lève une erreur informative.
        throw new Error(
            `Paiement par carte non encore disponible via Unipesa. ` +
            `Utilisez Mobile Money (Vodacom, Airtel, Orange, Africell) pour recharger votre wallet.`
        );

        // TODO: Implémenter le flux carte via Equity (provider ID 20) ou Ecobank (ID 23)
        // quand la documentation Unipesa carte sera disponible.
    }

    // ─────────────────────────────────────────────────────────────
    // 3. Retrait — vers Mobile Money
    // ─────────────────────────────────────────────────────────────

    async withdraw(userId, amountRaw, provider, phoneNumber) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!provider) throw new Error('Opérateur requis');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // Frais de retrait OLI : depuis config centralisée [P1.4]
        const OLI_WITHDRAW_FEE = FEES.OLI_WITHDRAW_RATE; // 3% par défaut
        const feeAmount    = amount * OLI_WITHDRAW_FEE;
        const totalToDeduct = amount + feeAmount;

        // Vérification solde (doit couvrir montant + frais)
        const balance = await walletRepository.getBalance(userId);
        if (balance < totalToDeduct) {
            throw new Error(
                `Solde insuffisant (disponible: ${balance.toFixed(2)} FC, ` +
                `requis: ${totalToDeduct.toFixed(2)} FC incluant ${(OLI_WITHDRAW_FEE * 100)}% de frais)`
            );
        }

        const reference = `WD-${userId}-${Date.now()}`; // FORMAT OFFICIEL : tirets (aligné avec unipesa.service)

        // ── [FIX B3] : Débit immédiat via performDebit (remplace performWithdrawal inexistant) ──
        // Le débit est fait AVANT l'appel Unipesa pour empêcher tout double retrait.
        const withdrawResult = await walletRepository.performDebit(userId, totalToDeduct, {
            type: 'withdrawal_pending',
            provider: 'UNIPESA',
            reference,
            description: `Retrait vers ${provider} — ${amount.toFixed(0)} FC (+ ${feeAmount.toFixed(0)} FC frais)`,
            metadata: { netAmount: amount, feeAmount, provider, phoneNumber },
        });

        try {
            // ── [FIX B2] : Appel de la vraie méthode initiateWithdrawal (B2C) ─────────
            const amountFC = Math.round(amount);
            const unipesaRes = await unipesaService.initiateWithdrawal(
                userId,
                phoneNumber,
                amountFC // on envoie le NET (sans frais) vers le Mobile Money
            );

            // ✅ Retrait initié — les fonds arriveront après confirmation Unipesa
            // Les frais OLI sont immédiatement crédités à la Banque OLI
            await this._creditSystemWallet(
                feeAmount,
                `${reference}_FEE`,
                `Frais 3% retrait — ${amount.toFixed(0)} FC (User #${userId})`
            );

            // 🏦 OLI Bank — Ledger (non-bloquant)
            _recordToLedger(userId, 'withdrawal', amount, { reference, provider, fee: feeAmount });

            return {
                ...withdrawResult,
                oliOrderId:  unipesaRes.oliOrderId,
                status:      'pending',
                netAmountFC: amount,
                feeFC:       feeAmount,
                provider:    unipesaRes.provider,
                message:     `Retrait de ${amount.toFixed(0)} FC initié vers ${provider}.`,
            };

        } catch (err) {
            // Si l'appel Unipesa B2C échoue immédiatement → remboursement complet
            console.error(`❌ Unipesa B2C échoué, remboursement user #${userId}:`, err.message);
            await walletRepository.performDeposit(userId, totalToDeduct, {
                type: 'refund',
                provider: 'UNIPESA',
                reference: `${reference}_REFUND`,
                description: `Remboursement — échec retrait Unipesa: ${err.message}`,
            });
            throw new Error(err.message || "Impossible d'initier le décaissement Mobile Money");
        }
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

        const payResult = await walletRepository.performDebit(userId, amount, {
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
    async transferToUser(senderIdRaw, receiverIdRaw, amountRaw, currency = 'FC', io = null) {
        const senderId = parseInt(senderIdRaw);
        const receiverId = parseInt(receiverIdRaw);
        let amount = parseFloat(amountRaw);

        if (!senderId) throw new Error('Expéditeur invalide');
        if (!receiverId) throw new Error('Destinataire invalide');
        if (senderId === receiverId) throw new Error("Impossible de s'envoyer de l'argent à soi-même");
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (amount < 100) throw new Error('Montant trop faible (minimum 100 FC)');

        // Frais P2P : 1% à la charge de l'expéditeur
        const FEE_RATE = 0.01;
        const feeAmount = Math.round(amount * FEE_RATE);
        const totalDebit = amount + feeAmount; // L'expéditeur paie montant + frais

        const reference = `P2P_${Date.now()}_${senderId}_${receiverId}`;

        // Récupérer les noms pour les descriptions
        const usersRes = await pool.query(
            'SELECT id, name, phone FROM users WHERE id = ANY($1)', [[senderId, receiverId]]
        );
        const usersMap = {};
        usersRes.rows.forEach(u => { usersMap[u.id] = u; });
        const senderName = usersMap[senderId]?.name || `#${senderId}`;
        const receiverName = usersMap[receiverId]?.name || `#${receiverId}`;

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // — Débit expéditeur (montant + frais)
            const senderWallet = await walletRepository._getOrCreateWallet(senderId, client);
            if (senderWallet.is_frozen) throw new Error('Votre wallet est gelé');
            const senderBalance = parseFloat(senderWallet.balance);
            if (senderBalance < totalDebit) {
                throw new Error(`Solde insuffisant. Requis: ${totalDebit.toFixed(0)} FC (${amount.toFixed(0)} FC + ${feeAmount} FC frais), Disponible: ${senderBalance.toFixed(0)} FC`);
            }
            const newSenderBalance = senderBalance - totalDebit;
            await client.query(`UPDATE wallets SET balance = $1 WHERE id = $2`, [newSenderBalance, senderWallet.id]);
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newSenderBalance, senderId]);
            await walletRepository._insertTx(client, {
                walletId: senderWallet.id, userId: senderId, type: 'transfer',
                amount: -totalDebit, balanceAfter: newSenderBalance,
                provider: 'P2P', reference,
                description: `Envoi à ${receiverName} (frais ${feeAmount} FC inclus)`,
            });

            // — Crédit destinataire (montant net, sans les frais)
            const receiverWallet = await walletRepository._getOrCreateWallet(receiverId, client);
            if (receiverWallet.is_frozen) throw new Error('Le destinataire ne peut pas recevoir de fonds (wallet gelé)');
            const newReceiverBalance = parseFloat(receiverWallet.balance) + amount;
            await client.query(`UPDATE wallets SET balance = $1 WHERE id = $2`, [newReceiverBalance, receiverWallet.id]);
            await client.query(`UPDATE users SET wallet = $1 WHERE id = $2`, [newReceiverBalance, receiverId]);
            await walletRepository._insertTx(client, {
                walletId: receiverWallet.id, userId: receiverId, type: 'transfer',
                amount, balanceAfter: newReceiverBalance,
                provider: 'P2P', reference,
                description: `Reçu de ${senderName}`,
            });

            await client.query('COMMIT');

            // — Frais → Banque OLI (non-bloquant, hors transaction)
            if (feeAmount > 0) {
                this._creditSystemWallet(
                    feeAmount,
                    `${reference}_FEE`,
                    `Frais P2P 1% — ${senderName}→${receiverName} (${amount.toFixed(0)} FC)`
                ).catch(e => console.warn('⚠️ Frais P2P non crédités à la banque:', e.message));
            }

            // — Notification FCM au destinataire (non-bloquant)
            setImmediate(async () => {
                try {
                    const notifService = require('./notification.service');
                    await notifService.send(
                        receiverId, 'wallet',
                        `💸 Vous avez reçu ${amount.toFixed(0)} FC`,
                        `${senderName} vous a envoyé ${amount.toFixed(0)} FC via OLI Wallet`,
                        { type: 'transfer_received', amountFC: amount, senderId, reference },
                        io
                    );
                } catch (notifErr) {
                    console.warn('⚠️ Notification P2P non envoyée:', notifErr.message);
                }
            });

            console.log(`💸 Transfert P2P: #${senderId}(${senderName}) → #${receiverId}(${receiverName}) — ${amount.toFixed(0)} FC (frais: ${feeAmount} FC)`);

            return {
                success: true,
                amountFC: amount,
                feeFC: feeAmount,
                totalDebitFC: totalDebit,
                currency: 'FC',
                reference,
                receiverName,
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
