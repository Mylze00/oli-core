const fs = require('fs');
const json = JSON.parse(fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8'));
const spec = json.spec.data;

// Let's dump the info or tags that contain the provider list
if (spec.info && spec.info.description) {
    console.log(spec.info.description.substring(0, 1000));
}
if (spec.tags) {
    for (const tag of spec.tags) {
        if (tag.description) {
            console.log(tag.name);
            if (tag.description.includes('Available Payment Providers') || tag.description.includes('Provider')) {
                console.log(tag.description);
            }
        }
    }
}
