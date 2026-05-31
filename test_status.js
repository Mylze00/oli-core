const axios = require('axios');
const crypto = require('crypto');
const UNIPESA_API_URL = 'https://api.unipesa.tech';
const UNIPESA_PUBLIC_ID = 'cdeff30acb90445acfbefdc8b976ae5a25a68ee8';
const UNIPESA_SECRET = 'fac918290ee73cb3a94663fda145ebc5d3bb9b74b4b5dec2a2f11d314862bf1668f56492b8eb1efd1a14a969820d4bcf24f7a570f41738fdf0ae6ca350fd5047';
const UNIPESA_MERCHANT = 'cdef63c4cd8799e3edac01080748d7a3d8a543c6';

function _buildSignature(payload) {
    const sortedKeys = Object.keys(payload).filter(k => k !== 'signature');
    let str = '';
    for (const key of sortedKeys) {
        str += `${key}${payload[key]}`;
    }
    return crypto.createHmac('sha512', UNIPESA_SECRET).update(str).digest('hex').toLowerCase();
}

async function testStatus() {
    const payload = { merchant_id: UNIPESA_MERCHANT, order_id: 'DEP-122-1780130442918' };
    payload.signature = _buildSignature(payload);
    try {
        const response = await axios.post(`${UNIPESA_API_URL}/${UNIPESA_PUBLIC_ID}/status`, payload, { headers: { 'Content-Type': 'application/json' } });
        console.log('OK', response.data);
    } catch(e) {
        console.log('ERROR', e.response ? e.response.data : e.message);
    }
}
testStatus();
