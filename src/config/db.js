require("dotenv").config();
const { Pool } = require("pg");

/**
 * Configuration du Pool PostgreSQL
 * Utilise les variables décomposées pour une meilleure stabilité
 */
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: false, // Garder à false pour le développement local
});

// Log de diagnostic au démarrage
console.log(` Attempting to connect to DB: ${process.env.DB_NAME} as user: ${process.env.DB_USER}`);

/**
 * Événement : Connexion réussie
 */
pool.on("connect", () => {
  console.log("🐘 PostgreSQL connecté avec succès !");
});

/**
 * Événement : Erreur fatale PostgreSQL
 */
pool.on("error", (err) => {
  console.error("❌ Erreur PostgreSQL fatale :", err.message);
  // Ne pas tuer le processus immédiatement en dev, 
  // pour voir les autres logs de l'application
});

module.exports = pool;