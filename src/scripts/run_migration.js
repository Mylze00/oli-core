const fs = require('fs');
const { Pool } = require('pg');

// Chargement manuel super robuste du .env
try {
    const envConfig = fs.readFileSync('.env', 'utf8');
    envConfig.split('\n').forEach(line => {
        const [key, value] = line.split('=');
        if (key && value) {
            process.env[key.trim()] = value.trim();
        }
    });
} catch (e) {
    console.error("Impossible de lire .env", e);
}

async function runMigration() {
    console.log("DEBUG DATABASE_URL:", process.env.DATABASE_URL ? "OK" : "KO");

    // Détection SSL
    const isLocal = process.env.DATABASE_URL && (process.env.DATABASE_URL.includes('localhost') || process.env.DATABASE_URL.includes('127.0.0.1'));

    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: (process.env.DATABASE_URL && !isLocal) ? { rejectUnauthorized: false } : false
    });

    const migrationsDir = require('path').join(__dirname, 'migrations');

    try {
        const files = fs.readdirSync(migrationsDir).sort();
        console.log(`📂 Fichiers de migration trouvés: ${files.join(', ')}`);

        for (const file of files) {
            if (file.endsWith('.sql')) {
                const filePath = require('path').join(migrationsDir, file);
                const sql = fs.readFileSync(filePath, 'utf8');
                console.log(`🚀 Exécution migration: ${file}...`);
                await pool.query(sql);
                console.log(`✅ ${file} terminé !`);
            }
        }
        console.log("🎉 Toutes les migrations sont terminées !");
    } catch (err) {
        console.error("❌ Erreur:", err);
    } finally {
        await pool.end();
    }
}

runMigration();
