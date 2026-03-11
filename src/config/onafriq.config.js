/**
 * Configuration API Onafriq
 */
require("dotenv").config();

const ONAFRIQ_API_URL = process.env.ONAFRIQ_API_URL || "https://api.onafriq.com/api/v5";
const ONAFRIQ_CLIENT_ID = process.env.ONAFRIQ_CLIENT_ID || "";
const ONAFRIQ_CLIENT_SECRET = process.env.ONAFRIQ_CLIENT_SECRET || "";
const ONAFRIQ_ENVIRONMENT = process.env.ONAFRIQ_ENVIRONMENT || "sandbox"; // 'sandbox' ou 'production'

// Validation minimale au démarrage
if (!ONAFRIQ_CLIENT_ID || !ONAFRIQ_CLIENT_SECRET) {
    console.warn("⚠️ ATTENTION: ONAFRIQ_CLIENT_ID ou ONAFRIQ_CLIENT_SECRET non défini. Les appels à l'API Onafriq échoueront.");
}

module.exports = {
    ONAFRIQ_API_URL,
    ONAFRIQ_CLIENT_ID,
    ONAFRIQ_CLIENT_SECRET,
    ONAFRIQ_ENVIRONMENT,
    IS_SANDBOX: ONAFRIQ_ENVIRONMENT === "sandbox"
};
