import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  // Sur WSL2/Linux, 127.0.0.1 est le plus stable
  static const String baseUrl = "http://127.0.0.1:3000";

  Future<bool> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

      if (response.statusCode == 200) {
        print("✅ OTP envoyé : ${response.body}");
        return true;
      } else {
        print("❌ Erreur backend : ${response.body}");
        return false;
      }
    } catch (e) {
      print("🚨 Erreur de connexion : $e");
      return false;
    }
  }
}