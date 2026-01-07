const otpService = require("../services/otp.service");

(async () => {
  const phone = "+33611112222";

  // Générer et sauvegarder OTP
  const { user, otpCode } = await otpService.sendOtp(phone);
  console.log("OTP généré:", otpCode);

  // Vérifier OTP
  const verified = await otpService.verifyOtp(phone, otpCode);
  console.log("Vérification OTP:", verified);
})();
