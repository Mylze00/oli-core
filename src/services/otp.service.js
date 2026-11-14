const userRepo = require("../repositories/user.repository");
const smsService = require("./sms.service");

/**
 * Génère un OTP à 6 chiffres sous forme de String
 */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Compte réservé aux examinateurs Google Play.
 * Actif uniquement si REVIEW_PHONE et REVIEW_OTP sont définis dans le .env.
 * Ne s'applique qu'à ce numéro exact.
 */
function isReviewAccount(phone) {
  const { REVIEW_PHONE, REVIEW_OTP } = process.env;
  return Boolean(REVIEW_PHONE && REVIEW_OTP) && phone === REVIEW_PHONE;
}

/**
 * Envoie l'OTP (Logique de création/mise à jour utilisateur et stockage du code)
 */
async function sendOtp(phone, expiresMinutes = 5) {
  try {
    // 1. Chercher ou créer l'utilisateur
    let user = await userRepo.findByPhone(phone);
    if (!user) {
      user = await userRepo.createUser(phone);
      console.log(`👤 Nouvel utilisateur créé pour : ${phone}`);
    }

    // 2. Générer le code et la date d'expiration
    const review = isReviewAccount(phone);
    const otpCode = review ? process.env.REVIEW_OTP : generateOtp();
    const ttl = review ? 60 : expiresMinutes; // plus de temps pour les examinateurs
    const expiresAt = new Date(Date.now() + ttl * 60 * 1000);

    // 3. Sauvegarder en base de données via le repository
    await userRepo.saveOtp(user.id, otpCode, expiresAt);

    // 4. Envoyer le code par SMS (Infobip). Jamais pour le compte examinateur,
    //    dont le code est fixe. Sans configuration Infobip : comportement d'avant.
    if (!review) {
      if (smsService.isConfigured()) {
        await smsService.sendOtpSms(phone, otpCode, ttl);
      } else {
        console.warn("⚠️ [OTP] Infobip non configuré (INFOBIP_API_KEY / INFOBIP_BASE_URL) : aucun SMS envoyé");
      }
    }

    // ✅ Logs pour le débogage
    console.log(
      `✅ [OTP] Code généré: ${review ? "(compte examinateur)" : otpCode} pour ${phone}`
    );
    console.log(`⏱️ [OTP] Expire à: ${expiresAt.toLocaleTimeString()}`);

    return { user, otpCode }; // 👈 Retourner le code aussi
  } catch (error) {
    console.error("[OTP SERVICE] Erreur dans sendOtp:", error);
    throw error;
  }
}

/**
 * Vérifie l'OTP
 */
async function verifyOtp(phone, otpCode) {
  try {
    console.log(`[OTP SERVICE] 🔐 Tentative de vérification : ${phone} avec le code ${otpCode}`);

    // 1. Appeler le repository pour vérifier la correspondance phone/code/expiration
    const user = await userRepo.verifyOtp(phone, otpCode);

    if (!user) {
      console.log(`[OTP SERVICE] ❌ Échec : Code invalide ou expiré pour ${phone}`);
      return null;
    }

    // 2. Nettoyer l'OTP (SANS marquer comme vérifié automatiquement)
    // La vérification (badge) sera accordée par l'admin manuellement
    await userRepo.clearOtp(user.id);

    console.log(`[OTP SERVICE] ✅ Vérification réussie pour : ${phone}`);

    // 3. Retourner l'objet utilisateur (Correction de la variable inexistante ici)
    return { user };

  } catch (error) {
    console.error("[OTP SERVICE] Erreur dans verifyOtp:", error);
    throw error;
  }
}

module.exports = {
  sendOtp,
  verifyOtp,
};