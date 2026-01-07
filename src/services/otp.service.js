const userRepo = require("../repositories/user.repository");

/**
 * Génère un OTP à 6 chiffres sous forme de String
 */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + expiresMinutes * 60 * 1000);

    // 3. Sauvegarder en base de données via le repository
    await userRepo.saveOtp(user.id, otpCode, expiresAt);

    // ⚠️ LOG DEV : Très utile pour tester sans SMS réel
    console.log(`[OTP SERVICE] 📩 Code généré pour ${phone} : ${otpCode} (Expire à : ${expiresAt.toLocaleTimeString()})`);

    return { user, otpCode };
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

    // 2. Marquer l'utilisateur comme vérifié (optionnel selon votre logique métier)
    await userRepo.markVerified(user.id);

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