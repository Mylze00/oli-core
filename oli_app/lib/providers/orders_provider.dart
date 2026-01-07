import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/order_model.dart';
import '../secure_storage_service.dart';

// Base URL handled by ApiConfig


/// Provider pour récupérer les commandes de l'utilisateur
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final storage = SecureStorageService();
  final token = await storage.getToken();
  
  if (token == null) {
    throw Exception('Non authentifié');
  }
  
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/orders'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Order.fromJson(e)).toList();
  }
  
  throw Exception('Erreur ${response.statusCode}');
});

/// Service pour créer une commande
class OrderService {
  final SecureStorageService _storage = SecureStorageService();
  
  Future<Order?> createOrder({
    required List<OrderItem> items,
    String? deliveryAddress,
    String paymentMethod = 'wallet',
    double deliveryFee = 0,
  }) async {
    final token = await _storage.getToken();
    if (token == null) return null;
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'items': items.map((e) => e.toJson()).toList(),
        'deliveryAddress': deliveryAddress,
        'paymentMethod': paymentMethod,
        'deliveryFee': deliveryFee,
      }),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Order.fromJson(data['order']);
    }
    
    return null;
  }
  
  Future<bool> cancelOrder(int orderId) async {
    final token = await _storage.getToken();
    if (token == null) return false;
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    return response.statusCode == 200;
  }
  
  Future<bool> payOrder(int orderId, String paymentMethod) async {
    final token = await _storage.getToken();
    if (token == null) return false;
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/pay'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'paymentMethod': paymentMethod}),
    );
    
    return response.statusCode == 200;
  }
}

/// Provider du service de commandes
final orderServiceProvider = Provider<OrderService>((ref) => OrderService());
