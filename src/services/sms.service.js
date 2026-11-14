const axios = require("axios");

/**
 * Envoi de SMS via Infobip (https://www.infobip.com/docs/api/channels/sms).
 *
 * Variables d'environnement (à définir sur Render, jamais dans le code) :
 *   INFOBIP_API_KEY   clé API Infobip (portail → Outils pour les développeurs → Clés API)
 *   INFOBIP_BASE_URL  URL de base de votre compte, ex. « w4ednd.api.infobip.com »
 *   INFOBIP_SENDER    expéditeur affiché sur le téléphone, ex. « Oli » (facultatif,
 *                     sinon l'expéditeur de test d'Infobip pendant l'essai)
 *
 * Si INFOBIP_API_KEY ou INFOBIP_BASE_URL manque, aucun SMS n'est envoyé et
 * l'appli fonctionne comme avant (code visible uniquement dans les logs en dev).
 */

const TIMEOUT_MS = 10000;

function isConfigured() {
  return Boolean(process.env.INFOBIP_API_KEY && process.env.INFOBIP_BASE_URL);
}

/**
 * Numéro au format international sans « + » attendu par Infobip.
 * « +243 81 234 5678 » → « 243812345678 » ; « 0812345678 » (local RDC) → « 243812345678 ».
 */
function toInfobipNumber(phone) {
  let digits = String(phone).replace(/[^\d+]/g, "");
  if (digits.startsWith("+")) return digits.slice(1);
  if (digits.startsWith("00")) return digits.slice(2);
  if (digits.startsWith("0")) return "243" + digits.slice(1);
  return digits;
}

/**
 * Envoie un SMS texte. Lève une erreur (code « SMS_FAILED ») si Infobip refuse
 * le message ou ne répond pas.
 */
async function sendSms(phone, text) {
  const sender = process.env.INFOBIP_SENDER;
  if (!sender) return sendSmsFrom(phone, text, null);
  try {
    return await sendSmsFrom(phone, text, sender);
  } catch (error) {
    // Expéditeur personnalisé pas encore validé (enregistrement opérateurs en
    // cours…) : on renvoie avec l'expéditeur par défaut d'Infobip pour que le
    // code arrive quand même.
    console.warn(`⚠️ [SMS] Échec avec l'expéditeur « ${sender} », nouvel essai avec l'expéditeur par défaut`);
    return sendSmsFrom(phone, text, null);
  }
}

async function sendSmsFrom(phone, text, sender) {
  const baseUrl = process.env.INFOBIP_BASE_URL.replace(/^https?:\/\//, "").replace(/\/+$/, "");
  const to = toInfobipNumber(phone);
  const message = { destinations: [{ to }], text };
  if (sender) message.from = sender;

  try {
    const { data } = await axios.post(
      `https://${baseUrl}/sms/2/text/advanced`,
      { messages: [message] },
      {
        headers: {
          Authorization: `App ${process.env.INFOBIP_API_KEY}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        timeout: TIMEOUT_MS,
      }
    );

    const sent = data?.messages?.[0];
    const group = sent?.status?.groupName;
    // PENDING = accepté et en cours d'acheminement ; REJECTED = refusé
    if (!sent || group === "REJECTED" || group === "UNDELIVERABLE") {
      const reason = sent?.status?.description || "réponse inattendue";
      const err = new Error(`SMS refusé par Infobip : ${reason}`);
      err.code = "SMS_FAILED";
      throw err;
    }

    console.log(`📲 [SMS] Envoyé à ${to.slice(0, 6)}*** (statut ${group}, id ${sent.messageId})`);
    return { messageId: sent.messageId, status: group };
  } catch (error) {
    if (error.code === "SMS_FAILED") throw error;
    const detail =
      error.response?.data?.requestError?.serviceException?.text ||
      error.response?.status ||
      error.message;
    console.error(`❌ [SMS] Échec d'envoi Infobip : ${detail}`);
    const err = new Error(`Envoi SMS impossible : ${detail}`);
    err.code = "SMS_FAILED";
    throw err;
  }
}

/**
 * SMS du code de connexion. Reste sous 160 caractères (1 seul SMS facturé).
 */
async function sendOtpSms(phone, otpCode, expiresMinutes) {
  const text =
    `Oli : votre code de connexion est ${otpCode}. ` +
    `Il expire dans ${expiresMinutes} min. Ne le communiquez a personne.`;
  return sendSms(phone, text);
}

module.exports = {
  isConfigured,
  sendSms,
  sendOtpSms,
  toInfobipNumber,
};
