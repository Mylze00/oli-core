const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));
const spec = json.spec.data;

console.log(JSON.stringify(spec.components.schemas.customerIdDef, null, 2));
