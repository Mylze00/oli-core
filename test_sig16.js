require('dotenv').config();
const axios = require('axios');
const crypto = require('crypto');

const UNIPESA_API_URL = 'https://api.unipesa.tech';
const UNIPESA_PUBLIC_ID = 'cdeff30acb90445acfbefdc8b976ae5a25a68ee8';
const UNIPESA_SECRET = 'fac918290ee73cb3a94663fda145ebc5d3bb9b74b4b5dec2a2f11d314862bf1668f56492b8eb1efd1a14a969820d4bcf24f7a570f41738fdf0ae6ca350fd5047';
const UNIPESA_MERCHANT = 'cdef63c4cd8799e3edac01080748d7a3d8a543c6';

function _buildSignatureUnsorted(payload) {
    let str = '';
    for (const key of Object.keys(payload)) {
        if (key === 'signature') continue;
        str += `${key}${payload[key]}`;
    }
    return crypto.createHmac('sha512', UNIPESA_SECRET).update(str).digest('hex').toLowerCase();
}

async function testAll() {
    const payloadDeposit = {
        merchant_id: UNIPESA_MERCHANT,
        customer_id: '243827088682',
        order_id: 'test-P1',
        amount: '500',
        currency: 'CDF'
    };
    payloadDeposit.signature = _buildSignatureUnsorted(payloadDeposit);
    try {
        const response = await axios.post(
            `${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/deposit`,
            payloadDeposit,
            { headers: { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0' } }
        );
        console.log(`[deposit] SUCCESS:`, response.data);
    } catch (e) {
        let data = e.response ? e.response.data : e.message;
        console.log(`[deposit] ERROR:`, data);
    }

    process.exit();
}
testAll();
