require('dotenv').config();
const axios = require('axios');
const crypto = require('crypto');

const UNIPESA_API_URL = 'https://api.unipesa.tech';
const UNIPESA_PUBLIC_ID = 'cdeff30acb90445acfbefdc8b976ae5a25a68ee8';
const UNIPESA_SECRET = 'fac918290ee73cb3a94663fda145ebc5d3bb9b74b4b5dec2a2f11d314862bf1668f56492b8eb1efd1a14a969820d4bcf24f7a570f41738fdf0ae6ca350fd5047';
const UNIPESA_MERCHANT = 'cdef63c4cd8799e3edac01080748d7a3d8a543c6';

function _buildSignature(payload) {
    const sortedKeys = Object.keys(payload).filter(k => k !== 'signature').sort();
    let str = '';
    for (const key of sortedKeys) {
        // IMPORTANT: The documentation might require nested sorting or stringifying?
        // Let's assume standard flat structure for now.
        if (typeof payload[key] === 'object') {
            str += `${key}${JSON.stringify(payload[key])}`;
        } else {
            str += `${key}${payload[key]}`;
        }
    }
    return crypto.createHmac('sha512', UNIPESA_SECRET).update(str).digest('hex').toLowerCase();
}

async function tryPayload(payload, label) {
    payload.signature = _buildSignature(payload);
    try {
        const response = await axios.post(
            `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/payment_c2b`,
            payload,
            { headers: { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0' } }
        );
        let msg = response.data;
        console.log(`[${label}] SUCCESS:`, msg);
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
    // According to paymentBody:
    // required: merchant_id, customer_id, customer_user_id, order_id, amount, currency, provider_id, signature
    const payload = {
        merchant_id: UNIPESA_MERCHANT,
        customer_id: '243827088682',
        customer_user_id: 'user-71',
        order_id: 'test-M1',
        amount: '500',
        currency: 'CDF',
        provider_id: 11
    };

    await tryPayload(payload, 'payment_c2b');

    process.exit();
}
testAll();
