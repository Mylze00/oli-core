class ApiConfig {
  // URL de production (Render)
  static const String baseUrl = 'https://oli-core.onrender.com';
  
  // URL de développement (décommenter pour tester en local)
  // static const String baseUrl = 'http://127.0.0.1:3000'; 
  
  // Endpoints
  static const String auth = '$baseUrl/auth';
  static const String products = '$baseUrl/products';
  static const String orders = '$baseUrl/orders';
  static const String wallet = '$baseUrl/wallet';
  static const String chat = '$baseUrl/chat';
  static const String chatConversations = '$baseUrl/chat/conversations';
  static const String chatMessages = '$baseUrl/chat/messages';
  static const String shops = '$baseUrl/api/shops';
}

