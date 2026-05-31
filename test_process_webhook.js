require('dotenv').config();
const pool = require('./src/config/db');
const unipesaService = require('./src/services/unipesa.service');
async function run() {
    try {
        console.log('Testing processWebhook...');
        const res = await unipesaService.processWebhook({
            order_id: 'DEP-122-1780130442918',
            status: 1,
            amount: 1000
        });
        console.log('Result:', res);
    } catch(e) {
        console.log('Error:', e);
    }
    process.exit();
}
run();
