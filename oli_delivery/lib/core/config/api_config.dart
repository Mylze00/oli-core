class ApiConfig {
  static const String baseUrl = 'https://oli-core.onrender.com/api';
  
  static const String loginEndpoint = '$baseUrl/auth/login';
  static const String deliveryOrdersEndpoint = '$baseUrl/orders/delivery'; // New endpoint we will create
  static const String updateStatusEndpoint = '$baseUrl/orders'; // + /:id/status
}
