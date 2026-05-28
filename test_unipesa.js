require('dotenv').config();
const unipesaService = require('./src/services/unipesa.service');

async function test() {
    try {
        const res = await unipesaService.initiateDeposit(71, '243827088682', 500);
        console.log(res);
    } catch (e) {
        console.error("Error:", e);
    } finally {
        process.exit();
    }
}
test();
