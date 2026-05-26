const fs = require('fs');
const path = '/home/paolice-mylze/oli-core/src/services/wallet.service.js';
let c = fs.readFileSync(path, 'utf8');

const systemWalletMethod =     // ─────────────────────────────────────────────────────────────
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
            await client.query(\
                INSERT INTO users (id, name, email, phone, role, password, wallet)
                VALUES (0, 'Banque Crédit OLI', 'bank@oli-core.com', '+0000000000', 'admin', 'N/A', 0)
                ON CONFLICT (id) DO NOTHING
            \);
            
            // Obtenir le wallet système (le créera si inexistant)
            const sysWallet = await walletRepository._getOrCreateWallet(0, client);
            const newBalance = parseFloat(sysWallet.balance) + amount;
            
            await client.query('UPDATE wallets SET balance =  WHERE id = ', [newBalance, sysWallet.id]);
            await client.query('UPDATE users SET wallet =  WHERE id = 0', [newBalance]);
            
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
            console.log(\🏦 Banque OLI Créditée : +$\ (\)\);
        } catch (err) {
            await client.query('ROLLBACK');
            console.error('Erreur _creditSystemWallet :', err.message);
        } finally {
            client.release();
        }
    }

;

c = c.replace(
    '    // ─────────────────────────────────────────────────────────────\n    // 1. Recharge — Mobile Money',
    systemWalletMethod + '    // ─────────────────────────────────────────────────────────────\n    // 1. Recharge — Mobile Money'
);

// Modify deposit
c = c.replace(
    /async deposit\(userId, amountRaw, provider, phoneNumber\) {[\s\S]*?return await walletRepository.performDeposit\([\s\S]*?\}\);[\s\n]*\}/m,
    sync deposit(userId, amountRaw, provider, phoneNumber) {
        const amount = parseFloat(amountRaw);
        if (!amount || amount <= 0) throw new Error('Montant invalide');
        if (!provider) throw new Error('Opérateur Mobile Money requis');
        if (!phoneNumber) throw new Error('Numéro de téléphone requis');

        // Application des frais OLI (5%) - Le client paie 105% via Unipesa
        const feeAmount = amount * 0.05;
        const totalToCharge = amount + feeAmount;

        const reference = \DEP_\_\\;

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
            throw new Error(unipesaRes.message || 'Échec de l\\'initiation du dépôt');
        }

        // On enregistre le montant net que l'utilisateur recevra en attente. 
        // Les frais seront prélevés lors de la confirmation du webhook.
        return await walletRepository.performDeposit(userId, 0, {
            type: 'deposit_pending',
            provider: 'UNIPESA',
            reference: unipesaRes.transaction_id || reference,
            description: \Recharge initiée via \. En attente de validation PIN.\,
            metadata: { netAmount: amount, feeAmount: feeAmount }
        });
    }
);

// Modify withdraw
c = c.replace(
    /async withdraw\(userId, amountRaw, provider, phoneNumber\) {[\s\S]*?return withdrawResult;[\s\n]*\}/m,
    sync withdraw(userId, amountRaw, provider, phoneNumber) {
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
            throw new Error(\Solde insuffisant (disponible: $\, requis: $\ incluant 5% de frais)\);
        }

        const reference = \WD_\_\\;

        // IMPORTANT : Débit immédiat du Wallet OLI (Montant Total = Retrait + Frais) pour empêcher le double retrait
        const withdrawResult = await walletRepository.performWithdrawal(userId, totalToDeduct, {
            type: 'withdrawal_pending',
            provider: 'UNIPESA',
            reference,
            description: \Retrait vers \ ($\ + $\ frais)\,
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
                reference: \\_REFUND\,
                description: \Échec du retrait Unipesa - Remboursé\,
             });
             throw new Error(unipesaRes.message || "Impossible d'initier le décaissement externe");
        }

        // Le retrait a réussi au niveau de l'initiation. On crédite la Banque OLI avec les 5% de frais.
        await this._creditSystemWallet(feeAmount, \\_FEE\, \Frais 5% sur retrait de $\ (User #\)\);

        return withdrawResult;
    }
);

fs.writeFileSync(path, c);
console.log('wallet.service.js successfully updated.');
