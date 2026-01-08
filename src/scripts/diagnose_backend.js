const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes('render')
        ? { rejectUnauthorized: false }
        : false
});

const fs = require('fs');

async function diagnose() {
    console.log("🔍 DÉBUT DU DIAGNOSTIC BACKEND...");
    const envPath = path.resolve(__dirname, '../../.env');
    console.log("📍 Chemin visé :", envPath);

    if (fs.existsSync(envPath)) {
        console.log("✅ Le fichier .env existe sur le disque.");
        const content = fs.readFileSync(envPath, 'utf8');
        console.log("📄 Contenu (premiers 50 chars) :", content.substring(0, 50));
    } else {
        console.error("❌ ERREUR: Le fichier .env n'est pas trouvé par Node.js à cet endroit.");
    }

    require('dotenv').config({ path: envPath });

    // Fallback : Construction manuelle si DATABASE_URL manquant
    if (!process.env.DATABASE_URL && process.env.DB_USER) {
        console.log("⚠️ DATABASE_URL manquant, tentative de reconstruction...");
        const { DB_USER, DB_PASSWORD, DB_HOST, DB_NAME } = process.env;

        console.log("🔍 Debug Env Vars:");
        console.log("   - DB_USER:", !!DB_USER);
        console.log("   - DB_PASSWORD:", !!DB_PASSWORD, (DB_PASSWORD && typeof DB_PASSWORD));
        console.log("   - DB_HOST:", !!DB_HOST);
        console.log("   - DB_NAME:", !!DB_NAME);

        process.env.DATABASE_URL = `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${process.env.DB_PORT || 5432}/${DB_NAME}`;
    }

    console.log("❓ DATABASE_URL finale :", !!process.env.DATABASE_URL);

    if (!process.env.DATABASE_URL) {
        console.error("❌ ERREUR: Impossible de se connecter. Vérifiez .env");
        process.exit(1);
    }

    try {
        // 1. TEST CONNEXION
        const res = await pool.query('SELECT NOW()');
        console.log("✅ Connexion Base de données : OK", res.rows[0]);

        // 2. VÉRIFICATION DES COLONNES
        console.log("📊 Vérification du schéma de la table 'products'...");
        const schemaRes = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'products';
    `);

        const columns = schemaRes.rows.map(r => r.column_name);
        const required = ['condition', 'quantity', 'delivery_price', 'delivery_time', 'color', 'images'];

        const missing = required.filter(c => !columns.includes(c));

        if (missing.length > 0) {
            console.error("❌ COLONNES MANQUANTES :", missing);
            console.log("👉 Veuillez exécuter le script SQL de migration.");
        } else {
            console.log("✅ Toutes les colonnes requises sont présentes.");
        }

        // 3. TENTATIVE D'INSERTION DUMMY
        console.log("📝 Tentative d'insertion d'un produit (Test DB direct)...");

        // On cherche un utilisateur ID 1 ou premier dispo
        const userRes = await pool.query('SELECT id FROM users LIMIT 1');
        if (userRes.rows.length === 0) {
            console.log("⚠️ Aucun utilisateur trouvé pour tester l'insertion. Création d'un user test...");
            // Créer user test si besoin... 
        } else {
            const userId = userRes.rows[0].id;
            console.log(`👤 Test avec l'utilisateur ID: ${userId}`);

            const insertQuery = `
        INSERT INTO products (seller_id, name, description, price, category, images, delivery_price, delivery_time, condition, quantity, color) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) 
        RETURNING id
      `;

            const values = [
                userId,
                "Produit Test Diagnostic",
                "Description test",
                99.99,
                "TestCategory",
                ["img1.jpg", "img2.jpg"],
                5.00,
                "2-3 jours",
                "Neuf",
                10,
                "Rouge"
            ];

            const insertRes = await pool.query(insertQuery, values);
            console.log("✅ INSERTION RÉUSSIE ! ID Produit :", insertRes.rows[0].id);

            // Nettoyage
            await pool.query('DELETE FROM products WHERE id = $1', [insertRes.rows[0].id]);
            console.log("✅ Produit de test nettoyé.");
        }

        console.log("🎉 DIAGNOSTIC TERMINÉ AVEC SUCCÈS. LE BACKEND SEMBLE OK.");

    } catch (err) {
        console.error("❌ ERREUR FATALE DURANT LE DIAGNOSTIC :", err.message);
        if (err.message.includes('column')) {
            console.log("👉 C'est une erreur de structure de base de données. Il faut mettre à jour la BDD.");
        }
    } finally {
        pool.end();
    }
}

diagnose();
