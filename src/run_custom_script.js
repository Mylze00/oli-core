const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const pool = require('./config/db');

async function runCustomScript() {
    // Get the script path from the command line argument (e.g., node src/run_custom_script.js src/scripts/myscript.sql)
    const scriptRelativePath = process.argv[2];

    if (!scriptRelativePath) {
        console.error("❌ Usage: node src/run_custom_script.js <path_to_sql_file>");
        process.exit(1);
    }

    const scriptPath = path.resolve(process.cwd(), scriptRelativePath);

    try {
        if (!fs.existsSync(scriptPath)) {
            throw new Error(`File not found: ${scriptPath}`);
        }

        const sql = fs.readFileSync(scriptPath, 'utf8');
        console.log(`📜 Executing script: ${scriptRelativePath}`);

        await pool.query(sql);
        console.log("✅ Script executed successfully!");
    } catch (err) {
        console.error("❌ Script execution failed:", err.message);
    } finally {
        await pool.end();
    }
}

runCustomScript();
