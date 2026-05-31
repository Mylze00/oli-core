const fs = require('fs');
const content = fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8');
const spec = JSON.parse(content).spec.data;

const description = spec.info.description;
const lines = description.split('\n');
let print = false;
for (const line of lines) {
    if (line.includes('Available Payment Providers') || line.includes('Available payment providers')) {
        print = true;
    }
    if (print) {
        console.log(line);
        if (line.includes('###') && !line.includes('Providers')) {
            print = false;
        }
    }
}
