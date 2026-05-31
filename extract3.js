const fs = require('fs');
const content = fs.readFileSync('/mnt/c/Users/Paolice/.gemini/antigravity/brain/d3e7f91c-5964-41dd-8bc1-cf5f4406606b/.system_generated/steps/1089/content.md', 'utf8');

const match = content.match(/const __redoc_state = ({.*});/);
if (match) {
    const jsonStr = match[1];
    fs.writeFileSync('/home/paolice-mylze/oli-core/openapi.json', jsonStr);
    console.log('Saved to openapi.json, length:', jsonStr.length);
} else {
    console.log('Not found');
}
