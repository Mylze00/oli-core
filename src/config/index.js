/**
 * Configuration centralisée Oli
 * Toutes les constantes et variables d'environnement sont gérées ici
 */
require("dotenv").config();

// ─────────────────────────────────────────────────────────────────────────────
// [P1.1] SÉCURITÉ — JWT
// En production, le serveur refuse de démarrer sans JWT_SECRET.
// En développement, un warning est affiché et un secret temporaire est utilisé.
// ─────────────────────────────────────────────────────────────────────────────
const NODE_ENV = process.env.NODE_ENV || "development";
const IS_PRODUCTION = NODE_ENV === "production";

if (!process.env.JWT_SECRET) {
    if (IS_PRODUCTION) {
        console.error("❌ FATAL: JWT_SECRET non défini en production. Arrêt immédiat.");
        console.error("   → Ajoutez JWT_SECRET dans vos variables d'environnement Render/Railway/Fly.io");
        process.exit(1);
    } else {
        console.warn("⚠️  [DEV ONLY] JWT_SECRET non défini. Secret de développement temporaire utilisé.");
        console.warn("   → NE JAMAIS déployer sans définir JWT_SECRET en production !");
    }
}

const JWT_SECRET    = process.env.JWT_SECRET || "oli_dev_secret_NOT_FOR_PRODUCTION_" + Date.now();
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "30d";

// ─────────────────────────────────────────────────────────────────────────────
// [P1.4] FRAIS — Source unique de vérité pour TOUS les taux de frais OLI
// Lisibles depuis l'environnement pour ajustement sans re-déploiement.
// ─────────────────────────────────────────────────────────────────────────────
const FEES = {
    // Frais de dépôt Mobile Money (C2B)
    OLI_DEPOSIT_RATE:        parseFloat(process.env.OLI_DEPOSIT_FEE_RATE   || "0.03"), // 3% OLI
    AGGREGATOR_DEPOSIT_RATE: parseFloat(process.env.UNIPESA_FEE_RATE       || "0.03"), // 3% Unipesa
    get TOTAL_DEPOSIT_RATE() { return this.OLI_DEPOSIT_RATE + this.AGGREGATOR_DEPOSIT_RATE; }, // 6%

    // Frais de retrait Mobile Money (B2C)
    OLI_WITHDRAW_RATE:       parseFloat(process.env.OLI_WITHDRAW_FEE_RATE  || "0.03"), // 3% OLI

    // Frais sur paiements de commandes (escrow)
    OLI_ORDER_RATE:          parseFloat(process.env.OLI_ORDER_FEE_RATE     || "0.03"), // 3% OLI
};

// ─────────────────────────────────────────────────────────────────────────────
// TAUX DE CHANGE — Valeur de secours uniquement (utiliser exchange-rate.service en prod)
// ─────────────────────────────────────────────────────────────────────────────
const FC_TO_USD_FALLBACK = parseFloat(process.env.FC_TO_USD_FALLBACK || "2800");

// ─────────────────────────────────────────────────────────────────────────────
// URLs
// ─────────────────────────────────────────────────────────────────────────────
const BASE_URL     = process.env.BASE_URL     || "https://oli-core.onrender.com";
const FRONTEND_URL = process.env.FRONTEND_URL || "https://oli-core.web.app";

// ─────────────────────────────────────────────────────────────────────────────
// CORS — Liste blanche des origines autorisées
// ─────────────────────────────────────────────────────────────────────────────
const DEFAULT_ORIGINS = [
    "https://oli-core.web.app",
    "https://oli-core.firebaseapp.com",
    "https://oli-app.web.app",
    "https://oli-app.firebaseapp.com",
    // Delivery App Firebase
    "https://olidelivery.web.app",
    "https://olidelivery.firebaseapp.com",
    // Admin Dashboard Vercel
    "https://oli-admin-windx.vercel.app",
    "https://oli-admin-efls2c6tm-mylze00s-projects.vercel.app",
    "https://oli-admin-smoky.vercel.app",
    // Backend & Seller Center (Render)
    "https://oli-core.onrender.com",
    "https://oli-seller.onrender.com",
    // Seller Center (Vercel)
    "https://oli-seller.vercel.app",
    // Local development
    "http://localhost:3000",
    "http://localhost:3001",
    "http://localhost:5000",
    "http://localhost:5173",
    "http://127.0.0.1:3000"
];

const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim())
    : DEFAULT_ORIGINS;

if (ALLOWED_ORIGINS.includes('*')) {
    if (IS_PRODUCTION) {
        console.error("❌ FATAL: ALLOWED_ORIGINS contient '*' en production. Arrêt immédiat.");
        process.exit(1);
    }
    console.warn("⚠️  [DEV ONLY] ALLOWED_ORIGINS est '*' — dangereux en production !");
}

// ─────────────────────────────────────────────────────────────────────────────
// UPLOAD
// ─────────────────────────────────────────────────────────────────────────────
const UPLOAD_MAX_SIZE  = parseInt(process.env.UPLOAD_MAX_SIZE)  || 5 * 1024 * 1024; // 5MB
const UPLOAD_MAX_FILES = parseInt(process.env.UPLOAD_MAX_FILES) || 8;

// ─────────────────────────────────────────────────────────────────────────────
// OTP
// ─────────────────────────────────────────────────────────────────────────────
const OTP_EXPIRY_MINUTES  = parseInt(process.env.OTP_EXPIRY_MINUTES)  || 5;
const OTP_MAX_ATTEMPTS    = parseInt(process.env.OTP_MAX_ATTEMPTS)    || 5;  // [Phase 2]
const OTP_LOCKOUT_MINUTES = parseInt(process.env.OTP_LOCKOUT_MINUTES) || 15; // [Phase 2]
const OTP_LENGTH = 6;

// ─────────────────────────────────────────────────────────────────────────────
// SERVEUR
// ─────────────────────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT) || 3000;

module.exports = {
    // Sécurité
    JWT_SECRET,
    JWT_EXPIRES_IN,

    // [P1.4] Frais — source unique de vérité
    FEES,
    FC_TO_USD_FALLBACK,

    // URLs
    BASE_URL,
    FRONTEND_URL,

    // CORS
    ALLOWED_ORIGINS,

    // Upload
    UPLOAD_MAX_SIZE,
    UPLOAD_MAX_FILES,

    // AWS S3 / Wasabi
    S3_BUCKET:             process.env.S3_BUCKET || "oli-storage",
    S3_REGION:             process.env.S3_REGION || "us-east-1",
    S3_ENDPOINT:           process.env.S3_ENDPOINT || "https://s3.wasabisys.com",
    AWS_ACCESS_KEY_ID:     process.env.AWS_ACCESS_KEY_ID || "",
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY || "",

    // Mobile Money (Orange legacy)
    ORANGE_MONEY_API_URL:    process.env.ORANGE_MONEY_API_URL || "https://api.orange.com/orange-money-webpay/dev/v1",
    ORANGE_MONEY_CLIENT_ID:  process.env.ORANGE_MONEY_CLIENT_ID || "",
    ORANGE_MONEY_CLIENT_SECRET: process.env.ORANGE_MONEY_CLIENT_SECRET || "",
    MOBILE_MONEY_SANDBOX:    process.env.MOBILE_MONEY_SANDBOX !== "false",

    // OTP
    OTP_EXPIRY_MINUTES,
    OTP_MAX_ATTEMPTS,
    OTP_LOCKOUT_MINUTES,
    OTP_LENGTH,

    // Serveur
    PORT,
    NODE_ENV,
    IS_PRODUCTION,
};
