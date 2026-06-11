/**
 * Routes d'authentification Oli
 * Connexion par téléphone + OTP + Gestion Profil
 */
const express = require("express");
const authController = require("../controllers/auth.controller");
const { requireAuth } = require("../middlewares/auth.middleware");
const { avatarUpload } = require("../config/upload");
const { otpSendLimiter, otpVerifyLimiter } = require("../middlewares/rate-limiter.middleware");

const router = express.Router();

// --- Auth Publique --- [SÉCU: Rate limitée contre le brute-force]
router.post("/send-otp",   otpSendLimiter,   authController.sendOtp);
router.post("/verify-otp", otpVerifyLimiter, authController.verifyOtp);

// --- Auth Requise ---
router.post("/update-profile", requireAuth, authController.updateProfile);
router.get("/me", requireAuth, authController.getMe);
router.post("/upload-avatar", requireAuth, avatarUpload.single('avatar'), authController.uploadAvatar);

module.exports = router;
