const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api/payment';

async function testPayment() {
    console.log("🚀 Démarrage du test de paiement simulé...");

    try {
        // 1. Créer Payment Intent
        console.log("\n1️⃣ Test create-payment-intent...");
        const response = await axios.post(`${BASE_URL}/create-payment-intent`, {
            amount: 2500, // 25.00$
            currency: 'usd',
            metadata: { orderId: '12345' }
        });

        console.log("✅ Réponse reçue:", response.data);

        if (response.data.id && response.data.id.startsWith('pi_')) {
            console.log("✅ ID PaymentIntent valide");
        } else {
            console.error("❌ ID PaymentIntent invalide");
        }

        if (response.data.client_secret) {
            console.log("✅ Client Secret présent");
        } else {
            console.error("❌ Client Secret manquant");
        }

        // 2. Test Webhook
        console.log("\n2️⃣ Test Webhook (Simulé)...");
        const webhookPayload = {
            type: 'payment_intent.succeeded',
            data: {
                object: response.data
            }
        };

        const webhookResponse = await axios.post(`${BASE_URL}/webhook`, webhookPayload);
        console.log("✅ Webhook Réponse:", webhookResponse.data);

    } catch (error) {
        console.error("❌ Erreur Test:", error.response ? error.response.data : error.message);
    }
}

testPayment();
