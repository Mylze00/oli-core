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
        str += `${key}${payload[key]}`;
    }
    return crypto.createHmac('sha512', UNIPESA_SECRET).update(str).digest('hex').toLowerCase();
}

async function tryParam(phoneKey) {
    try {
        const payload = {
            merchant_id: UNIPESA_MERCHANT,
            order_id: 'test-1234-' + phoneKey,
            amount: '500',
            currency: 'CDF',
            [phoneKey]: '243827088682',
            description: 'Test'
        };
        payload.signature = _buildSignature(payload);
        const response = await axios.post(
            `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/deposit`,
            payload,
            { headers: { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0' } }
        );
        console.log(`[${phoneKey}] Response:`, response.data.result.message || 'SUCCESS?');
    } catch (e) {
        // ignore
    }
}

async function testAll() {
    const keys = ['phoneNumber', 'msisdn', 'customer_phone', 'customer_number', 'mobile', 'cell', 'payer_phone', 'number', 'account_number'];
    for (let key of keys) {
        await tryParam(key);
    }
    process.exit();
}
testAll();
