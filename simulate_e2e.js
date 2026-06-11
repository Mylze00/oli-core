const axios = require('axios');
const API_URL = 'http://localhost:5000'; // Port par defaut
const MOCK_PHONE_SELLER = '+243990000001';
const MOCK_PHONE_BUYER = '+243990000002';
const MOCK_OTP = '123456'; // Selon l'implementation, on peut bypass en DEV

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runE2E() {
    console.log('🚀 Démarrage de la simulation E2E...');
    try {
        // NOTE: Ce script suppose que le serveur tourne localement.
        // Etape 1: Inscription/Connexion Vendeur
        console.log('\n--- 1. Connexion Vendeur (Alice) ---');
        let res = await axios.post(/auth/send-otp, { phone: MOCK_PHONE_SELLER });
        console.log('OTP envoyé à Alice:', res.data.message);
        
        res = await axios.post(/auth/verify-otp, { phone: MOCK_PHONE_SELLER, otpCode: MOCK_OTP });
        const sellerToken = res.data.token;
        console.log('✅ Alice connectée. Token:', sellerToken.substring(0, 15) + '...');

        // Etape 2: Inscription/Connexion Acheteur
        console.log('\n--- 2. Connexion Acheteur (Bob) ---');
        res = await axios.post(/auth/send-otp, { phone: MOCK_PHONE_BUYER });
        res = await axios.post(/auth/verify-otp, { phone: MOCK_PHONE_BUYER, otpCode: MOCK_OTP });
        const buyerToken = res.data.token;
        console.log('✅ Bob connecté. Token:', buyerToken.substring(0, 15) + '...');

        console.log('\n✅ Le script de base est prêt. Pour une simulation complète (Boutique, Produit, Commande, Chat), nous devons utiliser les endpoints exacts de votre API.');
    } catch (e) {
        console.error('❌ Erreur de simulation:', e.response ? e.response.data : e.message);
        console.log('Assurez-vous que le serveur local tourne (npm run dev).');
    }
}

runE2E();
