import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../services/secure_storage_service.dart';
import '../models/delivery_order_model.dart';

class DeliveryService {
  final SecureStorageService _storage = SecureStorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Commandes disponibles
  Future<List<DeliveryOrder>> getAvailableDeliveries() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/delivery/available'), headers: headers); // Note: Assuming baseUrl handles /api prefix implicitly or explicitly in ApiConfig
    // Wait, ApiConfig might be base URL without /api? 
    // Let's check api_config.dart content from memory or assume standard structure.
    // In step 307: static const String baseUrl = 'https://oli-core.onrender.com';
    // The server routes are mounted directly on app.use('/delivery', ...) in server.js?
    // In server.js (Step 293): app.use("/delivery", requireAuth, deliveryRoutes);
    // So URL is https://oli-core.onrender.com/delivery/available. Correct.

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => DeliveryOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load available deliveries: ${response.body}');
    }
  }

  // Mes livraisons
  Future<List<DeliveryOrder>> getMyTasks() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/delivery/my-tasks'), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => DeliveryOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load my tasks');
    }
  }

  // Accepter une livraison
  Future<DeliveryOrder> acceptDelivery(int id) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/delivery/$id/accept'), headers: headers);

    if (response.statusCode == 200) {
      return DeliveryOrder.fromJson(jsonDecode(response.body)['delivery']);
    } else {
      throw Exception('Failed to accept delivery: ${response.body}');
    }
  }

  // Mettre à jour le statut
  Future<DeliveryOrder> updateStatus(int id, String status, {double? lat, double? lng}) async {
    final headers = await _getHeaders();
    final body = jsonEncode({
      'status': status,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/delivery/$id/status'), 
      headers: headers,
      body: body
    );

    if (response.statusCode == 200) {
      return DeliveryOrder.fromJson(jsonDecode(response.body)['delivery']);
    } else {
      throw Exception('Failed to update status');
    }
  }
}
