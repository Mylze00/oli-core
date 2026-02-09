class ApiConfig {
  // URL de production (Render)
  static const String baseUrl = 'https://oli-core.onrender.com';
  
  // URL de développement (décommenter pour tester en local)
  // static const String baseUrl = 'http://127.0.0.1:3000'; 
  
  // --- Auth ---
  static const String auth = '$baseUrl/auth';
  static const String authSendOtp = '$baseUrl/auth/send-otp';
  static const String authVerifyOtp = '$baseUrl/auth/verify-otp';
  static const String authMe = '$baseUrl/auth/me';
  
  // --- Products ---
  static const String products = '$baseUrl/products';
  static const String productsFeatured = '$baseUrl/products/featured';
  static const String productsTopSellers = '$baseUrl/products/top-sellers';
  static const String productsVerifiedShops = '$baseUrl/products/verified-shops';
  static const String productsGoodDeals = '$baseUrl/products/good-deals';
  static const String ads = '$baseUrl/ads';
  
  // --- Orders ---
  static const String orders = '$baseUrl/orders';
  static String orderCancel(int id) => '$baseUrl/orders/$id/cancel';
  static String orderPay(int id) => '$baseUrl/orders/$id/pay';
  
  // --- Wallet ---
  static const String wallet = '$baseUrl/wallet';
  static const String walletBalance = '$baseUrl/wallet/balance';
  static const String walletTransactions = '$baseUrl/wallet/transactions';
  static const String walletDeposit = '$baseUrl/wallet/deposit';
  static const String walletWithdraw = '$baseUrl/wallet/withdraw';
  static const String walletDepositCard = '$baseUrl/wallet/deposit-card';
  
  // --- Chat ---
  static const String chat = '$baseUrl/chat';
  static const String chatConversations = '$baseUrl/chat/conversations';
  static const String chatMessages = '$baseUrl/chat/messages';
  
  // --- Shops ---
  static const String shops = '$baseUrl/api/shops';
  
  // --- Device Tokens (FCM) ---
  static const String deviceTokens = '$baseUrl/device-tokens';
  
  // --- Delivery ---
  static const String deliveryAvailable = '$baseUrl/delivery/available';
  static const String deliveryMyTasks = '$baseUrl/delivery/my-tasks';
  static String deliveryAccept(int id) => '$baseUrl/delivery/$id/accept';
  static String deliveryStatus(int id) => '$baseUrl/delivery/$id/status';
  static String deliveryVerify(int id) => '$baseUrl/delivery/$id/verify';
  
  // --- Notifications ---
  static const String notifications = '$baseUrl/notifications';
  
  // --- User Profile ---
  static const String userProfile = '$baseUrl/auth/profile';
  static const String authUploadAvatar = '$baseUrl/auth/upload-avatar';
  static const String userUpdateName = '$baseUrl/user/update-name';
  static const String userAvatar = '$baseUrl/auth/avatar';
  static const String userAddresses = '$baseUrl/auth/addresses';
}
