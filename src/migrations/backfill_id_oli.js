const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });
const pool = require('../config/db');

function generateIdOli(phone) {
    const last4 = phone ? phone.slice(-4) : '0000';
    const random = Math.floor(1000 + Math.random() * 9000); // 4 digits random
    return `OLI-${last4}-${random}`;
}

async function backfill() {
    try {
        console.log("🔄 Starting backfill of id_oli...");

        // 1. Get users without id_oli
        const res = await pool.query("SELECT id, phone FROM users WHERE id_oli IS NULL");
        const users = res.rows;

        console.log(`Found ${users.length} users to update.`);

        for (const user of users) {
            let idOli = generateIdOli(user.phone);

            // Check uniqueness (simple retry logic)
            let exists = await pool.query("SELECT 1 FROM users WHERE id_oli = $1", [idOli]);
            while (exists.rows.length > 0) {
                idOli = generateIdOli(user.phone);
                exists = await pool.query("SELECT 1 FROM users WHERE id_oli = $1", [idOli]);
            }

            await pool.query("UPDATE users SET id_oli = $1 WHERE id = $2", [idOli, user.id]);
            console.log(`✅ Updated User ${user.id} -> ${idOli}`);
        }

        console.log("🎉 Backfill completed!");
    } catch (err) {
        console.error("❌ Error backfilling:", err);
    } finally {
        await pool.end();
    }
}

backfill();
