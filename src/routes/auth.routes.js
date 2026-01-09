/**
 * Routes d'authentification Oli
 * Connexion par téléphone + OTP
 */
const express = require("express");
const jwt = require("jsonwebtoken");
const { JWT_SECRET, JWT_EXPIRES_IN } = require("../config");
const otpService = require("../services/otp.service");

const router = express.Router();

/**
 * POST /auth/send-otp
 * Envoie un code OTP au numéro de téléphone
 */
router.post("/send-otp", async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: "Numéro de téléphone requis" });
    }

    // Valider le format du numéro (RDC: +243...)
    const cleanPhone = phone.replace(/\s/g, '');
    if (!cleanPhone.match(/^\+?[0-9]{10,15}$/)) {
      return res.status(400).json({ error: "Format de numéro invalide" });
    }

    console.log("📩 SEND OTP:", cleanPhone);
    await otpService.sendOtp(cleanPhone);

    return res.json({
      message: "Code OTP envoyé",
      // En mode sandbox, on pourrait retourner le code pour les tests
      // otp: process.env.NODE_ENV === 'development' ? otpCode : undefined
    });

  } catch (e) {
    console.error("Erreur send-otp:", e);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

/**
 * POST /auth/verify-otp
 * Vérifie le code OTP et retourne un token JWT
 */
router.post("/verify-otp", async (req, res) => {
  try {
    const { phone, otpCode } = req.body;

    if (!phone || !otpCode) {
      return res.status(400).json({ error: "Téléphone et code OTP requis" });
    }

    console.log("🔐 VERIFY OTP:", phone, otpCode);

    const result = await otpService.verifyOtp(phone, otpCode);

    if (!result) {
      return res.status(401).json({ error: "Code invalide ou expiré" });
    }

    // Générer le token JWT avec toutes les infos utiles
    const token = jwt.sign(
      {
        id: result.user.id,
        phone: result.user.phone,
        is_seller: result.user.is_seller || false,
        is_deliverer: result.user.is_deliverer || false
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    return res.json({
      message: "Connexion réussie",
      user: {
        id: result.user.id,
        phone: result.user.phone,
        name: result.user.name,
        id_oli: result.user.id_oli,
        avatar_url: result.user.avatar_url,
        wallet: parseFloat(result.user.wallet || 0).toFixed(2),
        is_seller: result.user.is_seller || false,
        is_deliverer: result.user.is_deliverer || false,
      },
      token
    });

  } catch (e) {
    console.error("Erreur verify-otp:", e);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

/**
 * POST /auth/update-profile
 * Met à jour le profil utilisateur
 */
router.post("/update-profile", async (req, res) => {
  // Ce endpoint nécessite requireAuth mais il est géré dans server.js
  // On ajoute juste la logique ici
  const { name } = req.body;

  if (!req.user) {
    return res.status(401).json({ error: "Non authentifié" });
  }

  try {
    const pool = require("../config/db");
    const result = await pool.query(
      "UPDATE users SET name = $1, updated_at = NOW() WHERE phone = $2 RETURNING *",
      [name, req.user.phone]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Utilisateur non trouvé" });
    }

    res.json({
      message: "Profil mis à jour",
      user: result.rows[0]
    });
  } catch (e) {
    console.error("Erreur update-profile:", e);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

module.exports = router;
