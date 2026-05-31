const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));

// json.spec.data contains the OpenAPI spec
const spec = json.spec.data;

if (spec.paths) {
    for (const [path, methods] of Object.entries(spec.paths)) {
        if (path.includes('c2b') || path.includes('deposit')) {
            console.log('\n--- PATH:', path, '---');
            for (const [method, data] of Object.entries(methods)) {
                console.log(`METHOD: ${method}`);
                if (data.requestBody) {
                    console.log(JSON.stringify(data.requestBody, null, 2));
                }
            }
        }
    }
}
