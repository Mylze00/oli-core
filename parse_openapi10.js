const fs = require('fs');
const content = fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8');
const spec = JSON.parse(content).spec.data;

if (spec.tags) {
    for (const tag of spec.tags) {
        if (tag.description) {
            console.log('\n--- TAG:', tag.name, '---');
            console.log(tag.description.substring(0, 500));
        }
    }
}
