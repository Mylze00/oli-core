const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));

// json.spec.data contains the OpenAPI spec
const spec = json.spec.data;

if (spec.paths) {
    for (const [path, methods] of Object.entries(spec.paths)) {
        if (path.includes('c2b') || path.includes('deposit') || path.includes('payin')) {
            console.log('\n--- PATH:', path, '---');
            for (const [method, data] of Object.entries(methods)) {
                console.log(`METHOD: ${method}`);
                if (data.requestBody && data.requestBody.content) {
                    for (const [contentType, ctData] of Object.entries(data.requestBody.content)) {
                        console.log(`  ContentType: ${contentType}`);
                        if (ctData.schema) {
                            if (ctData.schema.properties) {
                                console.log('    Properties:', Object.keys(ctData.schema.properties).join(', '));
                                for (const [propName, propVal] of Object.entries(ctData.schema.properties)) {
                                    console.log(`      - ${propName}: ${propVal.type} (required: ${ctData.schema.required ? ctData.schema.required.includes(propName) : false})`);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
