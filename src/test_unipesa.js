require('dotenv').config({ path: './.env.local' });
const unipesaService = require('./services/unipesa.service');

async function testUnipesa() {
    try {
        console.log("🚀 Lancement du test Unipesa...");
        
        // On simule une recharge pour l'utilisateur 71 (toi)
        const userId = 71;
        const phone = "+243827088682";
        const amountFC = 500; // Montant minimum de test
        
        console.log(`📡 Envoi de la requête à Unipesa pour le numéro ${phone}...`);
        
        const result = await unipesaService.initiateDeposit(userId, phone, amountFC);
        
        console.log("✅ SUCCÈS ! La requête a été acceptée par Unipesa.");
        console.log("Détails de l'opération :", result);
        console.log("Vérifie ton téléphone, tu devrais recevoir le pop-up USSD d'ici quelques secondes.");
        
    } catch (error) {
        console.error("❌ ERREUR lors du test Unipesa :");
        console.error(error.message);
    } finally {
        process.exit(0);
    }
}

testUnipesa();
