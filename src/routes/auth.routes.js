const express = require("express");
const otpService = require("../services/otp.service");
const jwt = require("jsonwebtoken");
const JWT_SECRET = process.env.JWT_SECRET || "ton_secret_jwt_ici";

const router = express.Router();

/**
 * 📲 SEND OTP
 */
router.post("/send-otp", async (req, res) => {
  try {
    const { phone } = req.body;

    console.log("📩 SEND OTP:", phone);

    if (!phone) {
      return res.status(400).json({ error: "Phone required" });
    }

    const { otpCode } = await otpService.sendOtp(phone);

    return res.json({
      message: "OTP sent",
      otpCode // ⚠️ DEV ONLY
    });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
});

/**
 * 🔑 VERIFY OTP
 */
router.post("/verify-otp", async (req, res) => {
  try {
    const { phone, otpCode } = req.body;

    console.log("📩 VERIFY OTP:", phone, otpCode);

    const result = await otpService.verifyOtp(phone, otpCode);

    if (!result) {
      return res.status(401).json({ error: "Invalid or expired OTP" });
    }

    const token = jwt.sign(
      { id: result.user.id, phone: result.user.phone },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      message: "OTP verified",
      user: result.user,
      token
    });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;
