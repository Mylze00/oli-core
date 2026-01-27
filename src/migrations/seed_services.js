const pool = require('../config/db');

const services = [
    {
        name: 'SNEL',
        logo_url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/SNEL_logo.svg/1200px-SNEL_logo.svg.png', // Placeholder or real logo if found
        color_hex: '#FFA500', // Orange
        status: 'coming_soon',
        display_order: 1
    },
    {
        name: 'Regideso',
        logo_url: 'https://upload.wikimedia.org/wikipedia/fr/6/62/Regideso_RDC_logo.png',
        color_hex: '#2196F3', // Blue
        status: 'coming_soon',
        display_order: 2
    },
    {
        name: 'Canal+',
        logo_url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Canal%2B_logo_2011.svg/2560px-Canal%2B_logo_2011.svg.png',
        color_hex: '#000000', // Black
        status: 'coming_soon',
        display_order: 3
    },
    {
        name: 'Kelasipay',
        logo_url: 'https://pbs.twimg.com/profile_images/1691461937617694720/6k_K9q_4_400x400.jpg', // Placeholder
        color_hex: '#448AFF', // BlueAccent
        status: 'coming_soon',
        display_order: 4
    },
    {
        name: 'RAWSUR',
        logo_url: 'https://media.licdn.com/dms/image/v2/D4D0BAQFk0NfC5y0Iag/company-logo_200_200/company-logo_200_200/0/1683277717897?e=2147483647&v=beta&t=8-v1Q_PjJ_z_9-0_y_9-1_8-1', // Placeholder
        color_hex: '#3F51B5', // Indigo
        status: 'coming_soon',
        display_order: 5
    }
];

async function seedServices() {
    try {
        console.log("🌱 Seeding services...");

        // Clear existing to avoid duplicates if running multiple times (optional, safe for dev)
        // await pool.query('DELETE FROM services'); 

        for (const s of services) {
            // Check if exists
            const exists = await pool.query('SELECT id FROM services WHERE name = $1', [s.name]);
            if (exists.rows.length === 0) {
                await pool.query(
                    'INSERT INTO services (name, logo_url, color_hex, status, display_order) VALUES ($1, $2, $3, $4, $5)',
                    [s.name, s.logo_url, s.color_hex, s.status, s.display_order]
                );
                console.log(`✅ Inserted ${s.name}`);
            } else {
                console.log(`⚠️ ${s.name} already exists, skipping.`);
            }
        }
        console.log("✨ Seeding completed!");
    } catch (err) {
        console.error("❌ Seeding failed:", err);
    } finally {
        await pool.end();
    }
}

seedServices();
