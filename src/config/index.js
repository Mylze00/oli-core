/**
 * Configuration centralisée Oli
 * Toutes les constantes et variables d'environnement sont gérées ici
 */
require("dotenv").config();

// Sécurité
const JWT_SECRET = process.env.JWT_SECRET || "oli_default_secret_2024_secure_change_me";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "30d";

if (!process.env.JWT_SECRET) {
    console.warn("⚠️ ATTENTION: JWT_SECRET non défini. Utilisation du secret de secours.");
}

// URLs
const BASE_URL = process.env.BASE_URL || "https://oli-core.onrender.com";
const FRONTEND_URL = process.env.FRONTEND_URL || "https://oli-core.web.app";

// CORS
const DEFAULT_ORIGINS = [
    "https://oli-core.web.app",
    "https://oli-core.firebaseapp.com",
    "https://oli-app.web.app",
    "https://oli-app.firebaseapp.com",
    // Admin Dashboard Vercel
    "https://oli-admin-windx.vercel.app",
    "https://oli-admin-efls2c6tm-mylze00s-projects.vercel.app",
    "https://oli-admin-smoky.vercel.app",
    // Backend
    "https://oli-core.onrender.com",
    // Local development
    "http://localhost:3000",
    "http://localhost:5000",
    "http://127.0.0.1:3000"
];

const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim())
    : DEFAULT_ORIGINS;

if (ALLOWED_ORIGINS.length === 1 && ALLOWED_ORIGINS[0] === '*') {
    console.warn("⚠️ ALLOWED_ORIGINS est '*' — configuration non sécurisée pour la production");
}

// Upload
const UPLOAD_MAX_SIZE = parseInt(process.env.UPLOAD_MAX_SIZE) || 5 * 1024 * 1024; // 5MB
const UPLOAD_MAX_FILES = parseInt(process.env.UPLOAD_MAX_FILES) || 8;

// Mobile Money (pour Phase 1.5)
const ORANGE_MONEY_API_URL = process.env.ORANGE_MONEY_API_URL || "https://api.orange.com/orange-money-webpay/dev/v1";
const ORANGE_MONEY_CLIENT_ID = process.env.ORANGE_MONEY_CLIENT_ID || "";
const ORANGE_MONEY_CLIENT_SECRET = process.env.ORANGE_MONEY_CLIENT_SECRET || "";
const MOBILE_MONEY_SANDBOX = process.env.MOBILE_MONEY_SANDBOX !== "false"; // true par défaut

// OTP
const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES) || 5;
const OTP_LENGTH = 6;

// Serveur
const PORT = parseInt(process.env.PORT) || 3000;
const NODE_ENV = process.env.NODE_ENV || "development";
const IS_PRODUCTION = NODE_ENV === "production";

module.exports = {
    // Sécurité
    JWT_SECRET,
    JWT_EXPIRES_IN,

    // URLs
    BASE_URL,
    FRONTEND_URL,

    // CORS
    ALLOWED_ORIGINS,

    // Upload
    UPLOAD_MAX_SIZE,
    UPLOAD_MAX_FILES,

    // AWS S3 / Wasabi
    S3_BUCKET: process.env.S3_BUCKET || "oli-storage",
    S3_REGION: process.env.S3_REGION || "us-east-1",
    S3_ENDPOINT: process.env.S3_ENDPOINT || "https://s3.wasabisys.com",
    AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID || "",
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY || "",

    // Mobile Money
    ORANGE_MONEY_API_URL,
    ORANGE_MONEY_CLIENT_ID,
    ORANGE_MONEY_CLIENT_SECRET,
    MOBILE_MONEY_SANDBOX,

    // OTP
    OTP_EXPIRY_MINUTES,
    OTP_LENGTH,

    // Serveur
    PORT,
    NODE_ENV,
    IS_PRODUCTION,
};
