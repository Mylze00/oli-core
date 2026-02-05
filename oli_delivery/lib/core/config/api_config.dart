class ApiConfig {
  static const String baseUrl = 'https://oli-core.onrender.com';
  
  static const String sendOtpEndpoint = '$baseUrl/auth/send-otp';
  static const String verifyOtpEndpoint = '$baseUrl/auth/verify-otp';
  static const String deliveryOrdersEndpoint = '$baseUrl/delivery/available';
  static const String updateStatusEndpoint = '$baseUrl/orders'; // + /:id/status
}
