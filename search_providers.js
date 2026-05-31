const fs = require('fs');
const content = fs.readFileSync('/home/paolice-mylze/oli-core/openapi.json', 'utf8');

const regex = /.{0,50}(Vodacom|Airtel|Orange|Africell).{0,50}/g;
let m;
while ((m = regex.exec(content)) !== null) {
    console.log(m[0]);
}
