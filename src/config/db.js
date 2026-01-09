require("dotenv").config();
const { Pool } = require("pg");

/**
 * Configuration du Pool PostgreSQL
 * Utilise l'URL complète pour Render, ou les variables locales
 */
const isLocal = process.env.DATABASE_URL && (process.env.DATABASE_URL.includes('localhost') || process.env.DATABASE_URL.includes('127.0.0.1'));
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: (process.env.DATABASE_URL && !isLocal) ? { rejectUnauthorized: false } : false
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