const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));
const spec = json.spec.data;

const paymentBodyDeposit = spec.components.schemas.paymentBodyDeposit;
console.log('paymentBodyDeposit:');
console.log(JSON.stringify(paymentBodyDeposit, null, 2));

const providerDef = spec.components.schemas.providerDef;
console.log('providerDef:');
console.log(JSON.stringify(providerDef, null, 2));
