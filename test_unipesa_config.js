require('dotenv').config();
const axios = require('axios');
const crypto = require('crypto');
const config = require('./src/config/unipesa.config');

console.log('\n=== VERIFICATION CONFIG UNIPESA ===');
console.log('API URL     :', config.API_URL);
console.log('Public ID   :', config.PUBLIC_ID ? config.PUBLIC_ID.substring(0,10) + '...' : 'MANQUANT');
console.log('Merchant ID :', config.MERCHANT_ID ? config.MERCHANT_ID.substring(0,10) + '...' : 'MANQUANT');
console.log('Secret Key  :', config.SECRET_KEY ? config.SECRET_KEY.substring(0,6) + '...[' + config.SECRET_KEY.slice(-5) + ']' : 'MANQUANT');
console.log('IS_CONFIGURED:', config.IS_CONFIGURED ? 'MODE PRODUCTION' : 'MODE SIMULATEUR');

if (!config.IS_CONFIGURED) {
    console.log('\nConfiguration incomplete. Verifiez votre .env');
    process.exit(1);
}

async function testConnection() {
    console.log('\n=== TEST DE CONNEXION API UNIPESA ===');
    try {
        const payload = {
            merchant_id: config.MERCHANT_ID,
            order_id: 'TEST_CONNECTION_' + Date.now(),
        };
        let stringForSignature = '';
        for (const [key, value] of Object.entries(payload)) {
            stringForSignature += key + value;
        }
        payload.signature = crypto
            .createHmac('sha512', config.SECRET_KEY)
            .update(stringForSignature)
            .digest('hex')
            .toLowerCase();

        console.log('Envoi vers:', config.API_URL + '/' + config.PUBLIC_ID + '/status');
        const response = await axios.post(
            config.API_URL + '/' + config.PUBLIC_ID + '/status',
            payload,
            { headers: { 'Content-Type': 'application/json' }, timeout: 10000 }
        );
        console.log('Connexion API reussie !');
        console.log('Reponse:', JSON.stringify(response.data, null, 2));
    } catch (error) {
        if (error.response) {
            console.log('Connexion API etablie (serveur joignable)');
            console.log('Status HTTP:', error.response.status);
            console.log('Reponse API:', JSON.stringify(error.response.data, null, 2));
        } else {
            console.log('Impossible de joindre Unipesa:', error.message);
        }
    }
}
testConnection();
