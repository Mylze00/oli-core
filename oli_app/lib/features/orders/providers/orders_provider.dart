import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../models/order_model.dart';
import '../../../core/router/network/dio_provider.dart';

/// Provider pour récupérer les commandes de l'utilisateur
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final dio = ref.read(dioProvider);
  
  try {
    final response = await dio.get(ApiConfig.orders);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((e) => Order.fromJson(e)).toList();
    }
    
    throw Exception('Erreur ${response.statusCode}');
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      throw Exception('Non authentifié');
    }
    throw Exception('Erreur réseau: ${e.message}');
  }
});

/// Service pour créer une commande
class OrderService {
  final Dio _dio;
  
  OrderService(this._dio);
  
  Future<Order?> createOrder({
    required List<OrderItem> items,
    String? deliveryAddress,
    String paymentMethod = 'wallet',
    double deliveryFee = 0,
    String? deliveryMethodId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.orders,
        data: {
          'items': items.map((e) => e.toJson()).toList(),
          'deliveryAddress': deliveryAddress,
          'paymentMethod': paymentMethod,
          'deliveryFee': deliveryFee,
          if (deliveryMethodId != null) 'deliveryMethodId': deliveryMethodId,
        },
      );
      
      if (response.statusCode == 201) {
        return Order.fromJson(response.data['order']);
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Erreur création commande: $e');
      return null;
    }
  }
  
  Future<bool> cancelOrder(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderCancel(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur annulation commande: $e');
      return false;
    }
  }
  
  Future<bool> payOrder(int orderId, String paymentMethod) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderPay(orderId),
        data: {'paymentMethod': paymentMethod},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur paiement commande: $e');
      return false;
    }
  }
}

/// Provider du service de commandes
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.read(dioProvider));
});
