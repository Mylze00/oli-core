const fs = require('fs');
let file = fs.readFileSync('/home/paolice-mylze/oli-core/src/services/unipesa.service.js', 'utf8');

// 1. Remove .sort() from _buildSignature
file = file.replace(/const sortedKeys = Object\.keys\(payload\)\s*\.filter\(k => k !== 'signature'\)\s*\.sort\(\);/g, 'const sortedKeys = Object.keys(payload).filter(k => k !== \\'signature\\');');

// 2. Fix initiateDeposit payload and URL
file = file.replace(
    /const payload = \{\s*merchant_id: UNIPESA_MERCHANT,\s*order_id:\s*oliOrderId,\s*amount:\s*amountFC\.toString\(\),\s*currency:\s*'CDF', \/\/ Franc Congolais\s*phone:\s*phone\.replace\(\/\\D\/g, ''\)\.replace\(\/\^243\/, '0'\), \/\/ local format only\s*description: `Recharge OLI Wallet — \$\{amountFC\} FC`,\s*callback_url: 'https:\/\/oli-core\.onrender\.com\/webhooks\/unipesa\/deposit',\s*\};/g,
    `const providerName = _detectProvider(phone);
            const payload = {
                merchant_id: UNIPESA_MERCHANT,
                customer_id: _formatPhoneForProvider(phone, providerName),
                customer_user_id: \`user-\${userId}\`,
                order_id:    oliOrderId,
                amount:      Math.round(amountFC).toString(),
                currency:    'CDF',
                provider_id: _getProviderId(providerName),
                callback_url: 'https://oli-core.onrender.com/webhooks/unipesa/deposit',
            };`
);

file = file.replace(
    /\`\$\{UNIPESA_API_URL\}\/\$\{UNIPESA_PUBLIC_ID\}\/c2b\`/g,
    `\`\${UNIPESA_API_URL}/\${UNIPESA_PUBLIC_ID}/payment_c2b\``
);

// 3. Fix initiateWithdrawal payload and URL
file = file.replace(
    /const payload = \{\s*merchant_id: UNIPESA_MERCHANT,\s*order_id:\s*oliOrderId,\s*amount:\s*amountFC\.toString\(\),\s*currency:\s*'CDF',\s*phone:\s*phone\.replace\(\/\\D\/g, ''\)\.replace\(\/\^243\/, '0'\),\s*description: `Retrait OLI Wallet → Mobile Money — \$\{amountFC\} FC`,\s*callback_url: 'https:\/\/oli-core\.onrender\.com\/webhooks\/unipesa\/withdrawal',\s*\};/g,
    `const providerName = _detectProvider(phone);
            const payload = {
                merchant_id: UNIPESA_MERCHANT,
                customer_id: _formatPhoneForProvider(phone, providerName),
                customer_user_id: \`user-\${userId}\`,
                order_id:    oliOrderId,
                amount:      Math.round(amountFC).toString(),
                currency:    'CDF',
                provider_id: _getProviderId(providerName),
                callback_url: 'https://oli-core.onrender.com/webhooks/unipesa/withdrawal',
            };`
);

file = file.replace(
    /\`\$\{UNIPESA_API_URL\}\/\$\{UNIPESA_PUBLIC_ID\}\/b2c\`/g,
    `\`\${UNIPESA_API_URL}/\${UNIPESA_PUBLIC_ID}/payment_b2c\``
);

// 4. Add the missing helper functions at the end of the file
const helpers = `
/**
 * Convertit le nom du provider en ID provider AvadaPay.
 */
function _getProviderId(providerName) {
    switch (providerName) {
        case 'Vodacom': return 9;
        case 'Orange':  return 10;
        case 'Airtel':  return 17;
        case 'Africell':return 14;
        default:        return 9;
    }
}

/**
 * Formate le numéro de téléphone selon les règles strictes d'AvadaPay par opérateur.
 */
function _formatPhoneForProvider(phone, providerName) {
    let digits = phone.replace(/\\D/g, '');
    if (providerName === 'Airtel') {
        // Exige format 9XXXXXXXX (sans 0 ni 243)
        if (digits.startsWith('243')) digits = digits.slice(3);
        if (digits.startsWith('0')) digits = digits.slice(1);
    } else if (providerName === 'Orange') {
        // Exige format local avec le 0: 08XXXXXXXX
        if (digits.startsWith('243')) digits = '0' + digits.slice(3);
        if (!digits.startsWith('0')) digits = '0' + digits;
    } else {
        // Par défaut (Vodacom, Africell), format international complet 243
        if (digits.startsWith('0')) digits = '243' + digits.slice(1);
        if (digits.length === 9) digits = '243' + digits;
    }
    return digits;
}
`;

file = file.replace(/module\.exports = unipesaService;/g, helpers + '\nmodule.exports = unipesaService;');

fs.writeFileSync('/home/paolice-mylze/oli-core/src/services/unipesa.service.js', file);
