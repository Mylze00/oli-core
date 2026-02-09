class ApiConfig {
  static const String baseUrl = 'https://oli-core.onrender.com';

  // Auth
  static const String sendOtpEndpoint = '$baseUrl/auth/send-otp';
  static const String verifyOtpEndpoint = '$baseUrl/auth/verify-otp';
  static const String meEndpoint = '$baseUrl/auth/me';

  // Delivery — routes dédiées livreur
  static const String deliveryBase = '$baseUrl/delivery';
  static const String deliveryAvailable = '$deliveryBase/available';
  static const String deliveryMyTasks = '$deliveryBase/my-tasks';

  /// POST /delivery/:id/accept
  static String deliveryAccept(dynamic id) => '$deliveryBase/$id/accept';

  /// POST /delivery/:id/status  (body: {status, lat, lng})
  static String deliveryStatus(dynamic id) => '$deliveryBase/$id/status';

  /// POST /delivery/:id/verify  (body: {code})
  static String deliveryVerify(dynamic id) => '$deliveryBase/$id/verify';

  // Device tokens (FCM)
  static const String deviceTokens = '$baseUrl/device-tokens';
}
