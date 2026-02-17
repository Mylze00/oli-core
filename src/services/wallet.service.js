const walletRepository = require('../repositories/wallet.repository');
const mmService = require('./mobile-money.service');

class WalletService {

    async getBalance(userId) {
        return await walletRepository.getBalance(userId);
    }

    async getHistory(userId) {
        return await walletRepository.getHistory(userId);
    }

    async deposit(userId, amount, provider, phoneNumber) {
        // 1. Appel API Mobile Money simule
        const mmRes = await mmService.initiatePayment(provider, phoneNumber, amount);

        if (!mmRes.success || mmRes.status === 'failed') {
            throw new Error(mmRes.message || "Échec du paiement Mobile Money");
        }

        // 2. Transaction DB
        const result = await walletRepository.performDeposit(
            userId,
            amount,
            provider,
            mmRes.transaction_id,
            `Dépôt via ${provider}`
        );

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id,
            mmResult: mmRes
        };
    }

    async withdraw(userId, amount, provider, phoneNumber) {
        // 1. Vérification solde faite dans le repository (transaction atomique)
        // Mais on peut faire une pre-verification ici si on veut éviter l'appel API inutile
        const currentBalance = await walletRepository.getBalance(userId);
        if (currentBalance < amount) {
            throw new Error("Solde insuffisant");
        }

        // 2. Appel API Mobile Money
        const mmRes = await mmService.sendMoney(provider, phoneNumber, amount);

        // 3. Transaction DB
        const result = await walletRepository.performWithdrawal(
            userId,
            amount,
            provider,
            mmRes.transaction_id,
            `Retrait vers ${provider}`
        );

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id
        };
    }

    // PAIEMENT DE COMMANDE VIA WALLET
    async payOrder(userId, amount) {
        // 1. Vérification du solde
        const currentBalance = await walletRepository.getBalance(userId);
        if (currentBalance < amount) {
            throw new Error("Solde insuffisant");
        }

        // 2. Débit immédiat (Interne)
        const transactionId = `ORDER_${Date.now()}`;

        const result = await walletRepository.performWithdrawal(
            userId,
            amount,
            'WALLET_PAYMENT',
            transactionId,
            'Paiement de commande OLI'
        );

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id
        };
    }

    async depositByCard(userId, amount, cardInfo) {
        // Validation des informations de carte
        this._validateCard(cardInfo);

        // Simulation sandbox
        const cardNumber = cardInfo.cardNumber.replace(/\s/g, '');
        if (cardNumber.startsWith('4000')) {
            throw new Error('Carte refusée - Fonds insuffisants (simulation)');
        }

        const transactionId = `CARD_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        // Transaction DB
        const result = await walletRepository.performDeposit(
            userId,
            amount,
            'CARD',
            transactionId,
            `Dépôt par carte ****${cardNumber.slice(-4)}`
        );

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id,
            message: 'Paiement par carte réussi'
        };
    }

    /**
     * Créditer le vendeur après livraison validée
     * 100% du montant des produits vendus va au vendeur
     */
    async creditSeller(sellerId, amount, orderId) {
        const transactionId = `SALE_ORDER_${orderId}`;

        const result = await walletRepository.performDeposit(
            sellerId,
            amount,
            'SALE_CREDIT',
            transactionId,
            `Vente commande #${orderId}`
        );

        console.log(`   💰 Vendeur #${sellerId} crédité de ${amount}$ (commande #${orderId}). Nouveau solde: ${result.balanceAfter}$`);

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id
        };
    }

    _validateCard(cardInfo) {
        if (!cardInfo || !cardInfo.cardNumber || !cardInfo.expiryDate || !cardInfo.cvv) {
            throw new Error('Informations de carte incomplètes');
        }

        const cardNumber = cardInfo.cardNumber.replace(/\s/g, '');
        if (!/^\d{16}$/.test(cardNumber)) {
            throw new Error('Numéro de carte invalide (16 chiffres requis)');
        }

        if (!/^\d{3,4}$/.test(cardInfo.cvv)) {
            throw new Error('CVV invalide (3 ou 4 chiffres requis)');
        }

        if (!/^\d{2}\/\d{2}$/.test(cardInfo.expiryDate)) {
            throw new Error('Date d\'expiration invalide (format MM/YY requis)');
        }
    }

    /**
     * Transfert P2P entre utilisateurs (envoi cash via chat)
     */
    async transferToUser(senderId, receiverId, amount, currency = 'USD') {
        // Convertir FC en USD si nécessaire (taux fixe simplifié)
        let amountUSD = amount;
        if (currency === 'FC') {
            amountUSD = amount / 2800;
        }

        if (amountUSD <= 0) throw new Error("Montant invalide");
        if (senderId === receiverId) throw new Error("Impossible de s'envoyer de l'argent à soi-même");

        // Vérifier solde expéditeur
        const balance = await walletRepository.getBalance(senderId);
        if (balance < amountUSD) {
            throw new Error("Solde insuffisant");
        }

        const reference = `TRANSFER_${Date.now()}`;

        // 1. Débiter l'expéditeur
        const debit = await walletRepository.performWithdrawal(
            senderId,
            amountUSD,
            'P2P_TRANSFER',
            reference,
            `Envoi à utilisateur #${receiverId}`
        );

        // 2. Créditer le destinataire
        const credit = await walletRepository.performDeposit(
            receiverId,
            amountUSD,
            'P2P_TRANSFER',
            reference,
            `Reçu de utilisateur #${senderId}`
        );

        console.log(`💸 Transfert: #${senderId} → #${receiverId} — ${amountUSD.toFixed(2)}$ (${amount} ${currency})`);

        return {
            success: true,
            amountUSD,
            amountOriginal: amount,
            currency,
            senderNewBalance: debit.balanceAfter,
            receiverNewBalance: credit.balanceAfter,
            reference
        };
    }

    /**
     * Créditer le wallet du livreur après livraison confirmée
     */
    async creditDeliverer(delivererId, amount, orderId) {
        const transactionId = `DELIVERY_ORDER_${orderId}`;

        const result = await walletRepository.performDeposit(
            delivererId,
            amount,
            'DELIVERY_CREDIT',
            transactionId,
            `Commission livraison commande #${orderId}`
        );

        console.log(`   🚚💰 Livreur #${delivererId} crédité de ${amount}$ (commande #${orderId}). Nouveau solde: ${result.balanceAfter}$`);

        return {
            success: true,
            newBalance: result.balanceAfter,
            transactionId: result.id
        };
    }
}

module.exports = new WalletService();
