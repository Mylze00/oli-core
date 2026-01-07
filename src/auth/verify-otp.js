const otpService = require("../services/otp.service");

router.post("/verify-otp", async (req, res) => {
  try {
    const { phone, otpCode } = req.body;

    if (!phone || !otpCode) {
      return res.status(400).json({ error: "Phone and OTP code are required" });
    }

    // ⚡ Ici, verifyOtp retourne déjà { user, accessToken }
    const result = await otpService.verifyOtp(phone, otpCode);
    if (!result) {
      return res.status(401).json({ error: "Invalid or expired OTP" });
    }

    res.json({
      message: "OTP verified",
      accessToken: result.accessToken,
      user: {
        id: result.user.id,
        phone: result.user.phone,
      },
    });
  } catch (err) {
    console.error("❌ Error /verify-otp:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});
