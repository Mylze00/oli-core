/**
 * Webhook Controller pour Onafriq
 * 
 * Ce contrôleur intercepte les requêtes POST (callbacks) d'Onafriq
 * pour valider le statut des Collections (Dépôts) et Décaissements (Retraits)
 */
const walletRepository = require('../repositories/wallet.repository');
const onafriqService = require('../services/onafriq.service');

// Exemple de statut pour les transactions
const STATUS = {
    SUCCESS: 'SUCCESS', // Ou "COMPLETED" etc. selon spec Onafriq
    FAILED: 'FAILED',
    PENDING: 'PENDING'
};

class OnafriqWebhookController {
    
    /**
     * Endpoint: POST /webhooks/onafriq/collections
     * Callback lorsque l'utilisateur valide son PIN Mobile Money ou sa Carte
     */
    async handleCollection(req, res) {
        try {
            // Optionnel : vérifier que l'appel vient bien d'Onafriq
            // const signature = req.headers['x-onafriq-signature'];
            // if (!onafriqService.verifyWebhookSignature(signature, req.body)) {
            //    return res.status(401).json({ error: 'Signature invalide' });
            // }

            // Récupérer le corps du webhook
            const payload = req.body;
            console.log("📥 [WEBHOOK ONAFRIQ Collections] reçu:", JSON.stringify(payload, null, 2));
            
            // Adapter le modèle de données reçu selon la doc (id / status exact)
            // ex : { status: "SUCCESS", ... metadata: { oliTransactionId: "DEP_1_123456" } }
            // Voici un schéma possible extrait de requêtes typiques Onafriq
            const status = payload.status || (payload.remote_status === 'Successful' ? 'SUCCESS' : 'PENDING');
            const referenceId = payload.reference || payload.metadata?.oliTransactionId;
            const amount = parseFloat(payload.amount);

            if (!referenceId) {
                console.warn("⚠️ Callback Onafriq sans numéro de référence interne (oliTransactionId).");
                return res.status(400).send('Reference missing');
            }

            // Ex : 'DEP_userId_timestamp'
            const parts = referenceId.split('_'); 
            const type = parts[0];     // DEP (deposit)
            const userId = parseInt(parts[1]); 

            if (!userId) {
                throw new Error("UserId introuvable dans la référence.");
            }

            if (status === 'SUCCESS' || status === 'COMPLETED' || payload.remote_status === 'Successful') {
                 console.log(`✅ [WEBHOOK] Collection ${referenceId} complétée. Crédit du wallet de l'utilisateur ${userId}`);
                 
                 // IMPORTANT: A ce stade, la vraie transaction dans la base de données doit être finalisée
                 // Ici par simplicité on utilise performDeposit, mais en production un système anti-rebonds 
                 // (idempotence) est indispensable pour ne pas créditer deux fois.
                 await walletRepository.performDeposit(userId, amount, {
                    type: 'deposit',
                    provider: 'ONAFRIQ',
                    reference: referenceId,
                    description: `Recharge portefeuille via Onafriq`,
                 });

            } else if (status === 'FAILED') {
                 console.warn(`❌ [WEBHOOK] Collection ${referenceId} échouée.`);
                 // Mettre à jour l'état de la transaction "En attente" en statut "Refusé"
                 // ... await transactionRepository.updateStatus(referenceId, 'failed');
            } else {
                 console.warn(`⏳ [WEBHOOK] Statut en attente ou inconnu: ${status}`);
            }

            // Toujours retourner 200 à Onafriq pour qu'ils arrêtent d'envoyer le webhook
            return res.status(200).json({ status: 'ok' });

        } catch (error) {
            console.error("Erreur critique sur Webhook Onafriq (Collection):", error);
            // S'il y a une erreur technique grave 500 permettra à Onafriq de retenter plus tard
            return res.status(500).json({ error: "Erreur serveur webhook" });
        }
    }


    /**
     * Endpoint: POST /webhooks/onafriq/disbursements
     * Callback lorsqu'Onafriq a fini d'envoyer l'argent de OLI à l'utilisateur
     */
    async handleDisbursement(req, res) {
         try {
             const payload = req.body;
             console.log("📤 [WEBHOOK ONAFRIQ Disbursements] reçu:", JSON.stringify(payload, null, 2));

             const status = payload.status || (payload.remote_status === 'Successful' ? 'SUCCESS' : 'PENDING');
             const referenceId = payload.reference || payload.metadata?.oliTransactionId;

             if (status === 'SUCCESS' || payload.remote_status === 'Successful') {
                 console.log(`✅ [WEBHOOK] Décaissement ${referenceId} complété avec succès.`);
                 // La transaction a déjà été déduite du côté d'Oli (méthode withdraw), 
                 // on peut envoyer un mail/SMS à l'utilisateur pour le tenir au courant.
                 // await notificationService.send(userId, 'Retrait d\'argent réussi.');
             } else if (status === 'FAILED') {
                 console.warn(`❌ [WEBHOOK] Décaissement ${referenceId} échoué ! On doit RE-CREDITER le wallet de l'utilisateur !`);
                 
                 // IMPORTANT: Reverse la transaction car l'argent n'est jamais arrivé au client
                 // const parts = referenceId.split('_'); 
                 // const userId = parseInt(parts[1]); 
                 // const amount = parseFloat(payload.amount);
                 
                 /*
                 await walletRepository.performDeposit(userId, amount, {
                    type: 'refund',
                    provider: 'ONAFRIQ',
                    reference: `${referenceId}_REFUND`,
                    description: `Remboursement suite échec retrait Onafriq`,
                 });
                 */
             }

             return res.status(200).json({ status: 'ok' });

         } catch (error) {
            console.error("Erreur critique sur Webhook Onafriq (Disbursement):", error);
            return res.status(500).json({ error: "Erreur serveur" });
         }
    }

}

module.exports = new OnafriqWebhookController();
