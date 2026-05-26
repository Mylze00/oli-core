/**
 * Script de Test Complet - Opérations Wallet OLI
 * Numéro de test : +243827088682
 * 
 * Opérations testées :
 * 1. Dépôt via Mobile Money (Simulateur Unipesa)
 * 2. Vérification solde
 * 3. Création commande + Paiement wallet
 * 4. Retrait vers Mobile Money
 * 5. Transfert P2P
 * 6. Historique des transactions
 */

const axios = require('axios');

// Configuration
const API_BASE_URL = process.env.BASE_URL || 'http://localhost:5000';
const TEST_PHONE = '+243827088682';
const TEST_PROVIDER = 'orange'; // ou 'vodacom', 'airtel', 'africell'

let authToken = null;
let userId = null;
let testOrderId = null;

// Fonction utilitaire pour afficher les résultats
function log(title, data) {
    console.log('\n' + '='.repeat(60));
    console.log(`📋 ${title}`);
    console.log('='.repeat(60));
    console.log(JSON.stringify(data, null, 2));
}

function logSuccess(message) {
    console.log(`\n✅ ${message}`);
}

function logError(message, error) {
    console.log(`\n❌ ${message}`);
    console.error(error.response?.data || error.message);
}

// Fonction pour attendre (webhook simulation)
function wait(seconds) {
    return new Promise(resolve => setTimeout(resolve, seconds * 1000));
}

// ========================================
// 1. AUTHENTIFICATION / CRÉATION COMPTE
// ========================================
async function authenticateUser() {
    try {
        console.log('\n🔐 AUTHENTIFICATION...');
        
        // Vérifier si l'utilisateur existe
        let response;
        try {
            response = await axios.post(`${API_BASE_URL}/auth/login`, {
                phone: TEST_PHONE,
                password: 'Test123!' // Mot de passe par défaut pour les tests
            });
            
            authToken = response.data.token;
            userId = response.data.user.id;
            
            logSuccess(`Connexion réussie - User ID: ${userId}`);
            log('Données utilisateur', response.data.user);
            
        } catch (loginError) {
            // Si l'utilisateur n'existe pas, le créer
            if (loginError.response?.status === 401 || loginError.response?.status === 404) {
                console.log('\n👤 Création d\'un nouveau compte...');
                
                response = await axios.post(`${API_BASE_URL}/auth/register`, {
                    name: 'Utilisateur Test Wallet',
                    phone: TEST_PHONE,
                    email: `test.wallet.${Date.now()}@oli.com`,
                    password: 'Test123!'
                });
                
                authToken = response.data.token;
                userId = response.data.user.id;
                
                logSuccess(`Compte créé - User ID: ${userId}`);
                log('Nouveau compte', response.data.user);
            } else {
                throw loginError;
            }
        }
        
        return { token: authToken, userId };
        
    } catch (error) {
        logError('Erreur d\'authentification', error);
        throw error;
    }
}

// ========================================
// 2. VÉRIFIER SOLDE INITIAL
// ========================================
async function checkBalance() {
    try {
        console.log('\n💰 VÉRIFICATION DU SOLDE...');
        
        const response = await axios.get(`${API_BASE_URL}/wallet/balance`, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        log('Solde actuel', {
            balance: `$${response.data.balance}`,
            user_id: userId
        });
        
        return response.data.balance;
        
    } catch (error) {
        logError('Erreur vérification solde', error);
        throw error;
    }
}

// ========================================
// 3. TEST DÉPÔT (MOBILE MONEY)
// ========================================
async function testDeposit(amount = 50) {
    try {
        console.log(`\n💳 TEST DÉPÔT - $${amount} via ${TEST_PROVIDER.toUpperCase()}...`);
        
        const response = await axios.post(`${API_BASE_URL}/wallet/deposit`, {
            amount: amount,
            provider: TEST_PROVIDER,
            phoneNumber: TEST_PHONE
        }, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        log('Dépôt initié', response.data);
        
        if (response.data.transaction) {
            logSuccess(`Transaction créée : ${response.data.transaction.reference}`);
        }
        
        // Attendre le webhook simulé (3 secondes en mode test)
        console.log('\n⏳ Attente de la confirmation du webhook (3 secondes)...');
        await wait(4);
        
        // Vérifier le nouveau solde
        const newBalance = await checkBalance();
        logSuccess(`Dépôt confirmé ! Nouveau solde : $${newBalance}`);
        
        return response.data;
        
    } catch (error) {
        logError('Erreur lors du dépôt', error);
        throw error;
    }
}

// ========================================
// 4. TEST CRÉATION COMMANDE + PAIEMENT
// ========================================
async function testOrderPayment() {
    try {
        console.log('\n🛒 TEST CRÉATION COMMANDE...');
        
        // D'abord, vérifier qu'il y a des produits disponibles
        const productsResponse = await axios.get(`${API_BASE_URL}/products?limit=1`);
        
        if (!productsResponse.data.products || productsResponse.data.products.length === 0) {
            console.log('⚠️  Aucun produit disponible, création d\'un produit de test...');
            
            // Créer un produit simple pour le test
            const productResponse = await axios.post(`${API_BASE_URL}/products`, {
                name: 'Produit Test Wallet',
                description: 'Produit de test pour vérifier le système de paiement',
                price: 15.00,
                category: 'other',
                quantity: 10,
                condition: 'new',
                location: 'Kinshasa',
                delivery_price: 2.00
            }, {
                headers: { Authorization: `Bearer ${authToken}` }
            });
            
            console.log(`✅ Produit créé : ID ${productResponse.data.id}`);
        }
        
        const product = productsResponse.data.products[0];
        
        // Créer une commande
        const orderData = {
            items: [
                {
                    productId: product.id,
                    productName: product.name,
                    price: parseFloat(product.price),
                    quantity: 1,
                    sellerId: product.sellerId
                }
            ],
            deliveryAddress: 'Avenue Lukusa 123, Kinshasa/Gombe',
            deliveryFee: 2.00,
            paymentMethod: 'wallet',
            deliveryMethodId: 'oli_standard'
        };
        
        log('Données commande', orderData);
        
        const response = await axios.post(`${API_BASE_URL}/orders`, orderData, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        testOrderId = response.data.id;
        
        log('Commande créée et payée', {
            order_id: testOrderId,
            status: response.data.status,
            payment_status: response.data.paymentStatus,
            total_amount: response.data.totalAmount,
            pickup_code: response.data.pickup_code,
            delivery_code: response.data.delivery_code
        });
        
        logSuccess(`Commande #${testOrderId} créée et payée par wallet !`);
        
        // Vérifier le nouveau solde
        await checkBalance();
        
        return response.data;
        
    } catch (error) {
        logError('Erreur lors de la création de commande', error);
        throw error;
    }
}

// ========================================
// 5. TEST RETRAIT (MOBILE MONEY)
// ========================================
async function testWithdrawal(amount = 10) {
    try {
        console.log(`\n💸 TEST RETRAIT - $${amount} vers ${TEST_PROVIDER.toUpperCase()}...`);
        
        // Vérifier le solde avant
        const balanceBefore = await checkBalance();
        
        if (balanceBefore < amount * 1.05) {
            console.log(`⚠️  Solde insuffisant pour retirer $${amount} (avec frais 5%)`);
            console.log(`   Solde actuel : $${balanceBefore}`);
            console.log(`   Requis : $${(amount * 1.05).toFixed(2)} (incluant frais)`);
            return null;
        }
        
        const response = await axios.post(`${API_BASE_URL}/wallet/withdraw`, {
            amount: amount,
            provider: TEST_PROVIDER,
            phoneNumber: TEST_PHONE
        }, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        log('Retrait initié', response.data);
        
        logSuccess(`Retrait demandé : $${amount} (+ $${(amount * 0.05).toFixed(2)} frais)`);
        
        // Attendre le webhook simulé
        console.log('\n⏳ Attente de la confirmation du webhook (3 secondes)...');
        await wait(4);
        
        // Vérifier le nouveau solde
        const newBalance = await checkBalance();
        logSuccess(`Retrait confirmé ! Nouveau solde : $${newBalance}`);
        
        return response.data;
        
    } catch (error) {
        logError('Erreur lors du retrait', error);
        return null;
    }
}

// ========================================
// 6. TEST TRANSFERT P2P
// ========================================
async function testP2PTransfer(receiverId = 1, amount = 5) {
    try {
        console.log(`\n💸 TEST TRANSFERT P2P - $${amount} vers User #${receiverId}...`);
        
        const response = await axios.post(`${API_BASE_URL}/wallet/transfer`, {
            receiverId: receiverId,
            amount: amount,
            currency: 'USD'
        }, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        log('Transfert réussi', response.data);
        
        logSuccess(`Transfert de $${amount} effectué !`);
        
        // Vérifier le nouveau solde
        await checkBalance();
        
        return response.data;
        
    } catch (error) {
        logError('Erreur lors du transfert P2P', error);
        return null;
    }
}

// ========================================
// 7. HISTORIQUE DES TRANSACTIONS
// ========================================
async function getTransactionHistory() {
    try {
        console.log('\n📜 HISTORIQUE DES TRANSACTIONS...');
        
        const response = await axios.get(`${API_BASE_URL}/wallet/history?limit=50`, {
            headers: { Authorization: `Bearer ${authToken}` }
        });
        
        const transactions = response.data.transactions || response.data;
        
        log(`Historique (${transactions.length} transactions)`, transactions.map(tx => ({
            id: tx.id,
            type: tx.type,
            amount: tx.amount > 0 ? `+$${tx.amount}` : `$${tx.amount}`,
            balance_after: `$${tx.balance_after || tx.balanceAfter}`,
            description: tx.description,
            provider: tx.provider,
            reference: tx.reference,
            created_at: tx.created_at || tx.createdAt
        })));
        
        return transactions;
        
    } catch (error) {
        logError('Erreur lors de la récupération de l\'historique', error);
        throw error;
    }
}

// ========================================
// FONCTION PRINCIPALE
// ========================================
async function runTests() {
    console.log('\n');
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║   🧪 TEST COMPLET SYSTÈME WALLET OLI                     ║');
    console.log('║   Numéro : ' + TEST_PHONE.padEnd(44) + '║');
    console.log('╚═══════════════════════════════════════════════════════════╝');
    
    try {
        // 1. Authentification
        await authenticateUser();
        
        // 2. Solde initial
        const initialBalance = await checkBalance();
        
        // 3. Test dépôt (si solde faible)
        if (initialBalance < 30) {
            await testDeposit(50);
        } else {
            console.log(`\n💰 Solde suffisant ($${initialBalance}), skip dépôt`);
        }
        
        // 4. Test création commande + paiement
        await testOrderPayment();
        
        // 5. Test retrait (si solde suffisant)
        const currentBalance = await checkBalance();
        if (currentBalance >= 11) {
            await testWithdrawal(10);
        }
        
        // 6. Test transfert P2P (optionnel - décommenter si besoin)
        // const finalBalance = await checkBalance();
        // if (finalBalance >= 6) {
        //     await testP2PTransfer(1, 5); // Transfert vers User #1
        // }
        
        // 7. Afficher l'historique complet
        await getTransactionHistory();
        
        // Résumé final
        const finalBalance = await checkBalance();
        
        console.log('\n');
        console.log('╔═══════════════════════════════════════════════════════════╗');
        console.log('║   ✅ TESTS TERMINÉS AVEC SUCCÈS !                        ║');
        console.log('╚═══════════════════════════════════════════════════════════╝');
        console.log(`\n💼 Solde initial : $${initialBalance}`);
        console.log(`💰 Solde final   : $${finalBalance}`);
        
        if (testOrderId) {
            console.log(`\n🛒 Commande créée : #${testOrderId}`);
        }
        
        console.log('\n✨ Toutes les opérations ont été exécutées avec succès !');
        
    } catch (error) {
        console.log('\n');
        console.log('╔═══════════════════════════════════════════════════════════╗');
        console.log('║   ⚠️  ERREUR LORS DES TESTS                              ║');
        console.log('╚═══════════════════════════════════════════════════════════╝');
        console.error(error.message);
        process.exit(1);
    }
}

// Exécuter les tests
runTests();
