require("dotenv").config();
const { Pool } = require("pg");

/**
 * Configuration du Pool PostgreSQL
 * Utilise l'URL complète pour Render, ou les variables locales
 */
const pool = new Pool({
  connectionString: process.env.DATABASE_URL, // Utilise l'URL complète fournie par Render
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

// Log de diagnostic
console.log("🐘 Tentative de connexion à la base de données...");

pool.on("connect", () => {
  console.log("🐘 PostgreSQL connecté avec succès !");
});

pool.on("error", (err) => {
  console.error("❌ Erreur PostgreSQL fatale :", err.message);
});

module.exports = pool;