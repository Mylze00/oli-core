const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));
const spec = json.spec.data;

const paymentBody = spec.components.schemas.paymentBody;
console.log('paymentBody:');
console.log(JSON.stringify(paymentBody, null, 2));

console.log('\nOther schemas:');
for (const key of Object.keys(spec.components.schemas)) {
    if (key.toLowerCase().includes('deposit') || key.toLowerCase().includes('c2b') || key.toLowerCase().includes('payment')) {
        console.log(`- ${key}`);
    }
}
