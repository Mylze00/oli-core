/**
 * Simulator for Mobile Money Integrations (Orange Money, M-Pesa, Airtel)
 * En production, ce service sera remplacé par les vrais appels API.
 */
const { MOBILE_MONEY } = require('../config');

// Simulation de délais réseaux
const simulateNetworkDelay = () => new Promise(resolve => setTimeout(resolve, 1500));

class MobileMoneyService {

    /**
     * Initier un paiement (Dépôt vers Oli ou Paiement direct)
     * @param {string} provider - 'orange', 'mpesa', 'airtel'
     * @param {string} phoneNumber - Format +243...
     * @param {number} amount 
     * @param {string} currency - 'USD' ou 'CDF'
     */
    async initiatePayment(provider, phoneNumber, amount, currency = 'USD') {
        await simulateNetworkDelay();

        // Validation basique
        if (!['orange', 'mtn', 'mpesa', 'airtel'].includes(provider)) {
            throw new Error("Fournisseur non supporté");
        }

        if (amount <= 0) {
            throw new Error("Montant invalide");
        }

        // Simulation : Si le numéro termine par '00', échec
        if (phoneNumber.endsWith('00')) {
            return {
                success: false,
                status: 'failed',
                transaction_id: `TX-${Date.now()}-FAIL`,
                message: "Solde insuffisant (Simulation)"
            };
        }

        // Simulation : Si le numéro termine par '99', attente (pending)
        if (phoneNumber.endsWith('99')) {
            return {
                success: true,
                status: 'pending',
                transaction_id: `TX-${Date.now()}-PENDING`,
                message: "En attente de validation USSD"
            };
        }

        // Succès par défaut
        return {
            success: true,
            status: 'completed',
            transaction_id: `TX-${Date.now()}-${provider.toUpperCase()}`,
            provider_ref: `${provider.toUpperCase()}-${Math.floor(Math.random() * 100000)}`,
            message: "Paiement réussi"
        };
    }

    /**
     * Envoyer de l'argent (Retrait depuis Oli vers Mobile Money)
     */
    async sendMoney(provider, phoneNumber, amount, currency = 'USD') {
        await simulateNetworkDelay();

        // Logique similaire pour les retraits
        console.log(`💸 TRANSFERT VERS ${provider} (${phoneNumber}): ${amount} ${currency}`);

        return {
            success: true,
            status: 'completed',
            transaction_id: `WD-${Date.now()}-${provider.toUpperCase()}`,
            message: "Transfert effectué avec succès"
        };
    }

    /**
     * Vérifier le statut d'une transaction
     */
    async checkTransactionStatus(transactionId) {
        await simulateNetworkDelay();
        return {
            status: 'completed',
            updated_at: new Date()
        };
    }
}

module.exports = new MobileMoneyService();
