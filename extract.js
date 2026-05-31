const fs = require('fs');
const content = fs.readFileSync('/mnt/c/Users/Paolice/.gemini/antigravity/brain/d3e7f91c-5964-41dd-8bc1-cf5f4406606b/.system_generated/steps/1089/content.md', 'utf8');

const regex = /Redoc\.init\(['"]([^'"]+)['"]/;
const match = content.match(regex);
if (match) {
    console.log('Found URL:', match[1]);
} else {
    // maybe it is embedded as a Javascript object?
    const specRegex = /<redoc spec-url=['"]([^'"]+)['"]/;
    const match2 = content.match(specRegex);
    if (match2) {
        console.log('Found URL:', match2[1]);
    } else {
        const specEmbedded = /state="([^"]+)"/;
        const match3 = content.match(specEmbedded);
        if (match3) {
            console.log('Found embedded state, length:', match3[1].length);
            const decoded = Buffer.from(match3[1], 'base64').toString('utf8');
            try {
                // write to a file so I can view it
                const json = JSON.parse(decoded);
                fs.writeFileSync('/Ubuntu/home/paolice-mylze/oli-core/openapi.json', JSON.stringify(json, null, 2));
                console.log('Wrote embedded JSON to openapi.json');
            } catch(e) {
                console.log('Failed to parse embedded state');
            }
        } else {
            console.log('No URL or state found');
        }
    }
}
