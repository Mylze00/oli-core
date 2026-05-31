require('dotenv').config();
const axios = require('axios');
const crypto = require('crypto');

const UNIPESA_API_URL = 'https://api.unipesa.tech';
const UNIPESA_PUBLIC_ID = 'cdeff30acb90445acfbefdc8b976ae5a25a68ee8';
const UNIPESA_SECRET = 'fac918290ee73cb3a94663fda145ebc5d3bb9b74b4b5dec2a2f11d314862bf1668f56492b8eb1efd1a14a969820d4bcf24f7a570f41738fdf0ae6ca350fd5047';
const UNIPESA_MERCHANT = 'cdef63c4cd8799e3edac01080748d7a3d8a543c6';

async function tryPayload(payload, sigStr, label) {
    payload.signature = crypto.createHmac('sha512', UNIPESA_SECRET).update(sigStr).digest('hex').toLowerCase();
    try {
        const response = await axios.post(
            `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/deposit`,
            payload,
            { headers: { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0' } }
        );
        console.log(`[${label}] SUCCESS:`, response.data);
    } catch (e) {
        if (e.response && e.response.data) {
            let data = e.response.data;
            if (typeof data === 'string' && data.includes('<p>Signature')) data = 'Signature is not valid';
            console.log(`[${label}] ERROR:`, data);
        } else {
            console.log(`[${label}] ERROR:`, e.message);
        }
    }
}

async function testAll() {
    const payload = {
        merchant_id: UNIPESA_MERCHANT,
        order_id: 'test-D1',
        amount: '500',
        currency: 'CDF',
        customer_phone: '243827088682'
    };
    
    // Theory 1: They append 'descriptionnull'
    let sig1 = `amount500currencyCDFcustomer_phone243827088682descriptionnullmerchant_idcdef63c4cd8799e3edac01080748d7a3d8a543c6order_idtest-D1`;
    await tryPayload({...payload, order_id: 'test-D1'}, sig1, 'descriptionnull');

    // Theory 2: They append 'descriptionundefined'
    let sig2 = `amount500currencyCDFcustomer_phone243827088682descriptionundefinedmerchant_idcdef63c4cd8799e3edac01080748d7a3d8a543c6order_idtest-D2`;
    await tryPayload({...payload, order_id: 'test-D2'}, sig2, 'descriptionundefined');

    // Theory 3: They append 'description'
    let sig3 = `amount500currencyCDFcustomer_phone243827088682descriptionmerchant_idcdef63c4cd8799e3edac01080748d7a3d8a543c6order_idtest-D3`;
    await tryPayload({...payload, order_id: 'test-D3'}, sig3, 'description empty string');

    // Theory 4: It's NOT description, maybe it's just 'phone' instead of 'customer_phone' in the signature?
    let sig4 = `amount500currencyCDFmerchant_idcdef63c4cd8799e3edac01080748d7a3d8a543c6order_idtest-D4phone243827088682`;
    await tryPayload({...payload, order_id: 'test-D4'}, sig4, 'phone instead of customer_phone');

    process.exit();
}
testAll();
