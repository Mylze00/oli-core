const fs = require('fs');
const content = fs.readFileSync('/mnt/c/Users/Paolice/.gemini/antigravity/brain/d3e7f91c-5964-41dd-8bc1-cf5f4406606b/.system_generated/steps/1089/content.md', 'utf8');

// The Redocly standalone bundle embeds the spec in a div, or maybe inside an inline script.
// Let's find any JSON object that has "deposit" or "customer_phone"
const lines = content.split('\n');
for (let i=0; i<lines.length; i++) {
    if (lines[i].includes('deposit') || lines[i].includes('c2b') || lines[i].includes('amount')) {
        console.log(`Line ${i+1}: ${lines[i].substring(0, 150)}...`);
    }
}
