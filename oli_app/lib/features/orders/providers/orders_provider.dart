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
    String? mobileMoneyPhone,
    String? mobileMoneyProvider,
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
          if (mobileMoneyPhone != null && mobileMoneyPhone.isNotEmpty) 'mobileMoneyPhone': mobileMoneyPhone,
          if (mobileMoneyProvider != null && mobileMoneyProvider.isNotEmpty) 'mobileMoneyProvider': mobileMoneyProvider,
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

  /// Initie le paiement Mobile Money via Unipesa (déclenche le push USSD)
  /// Retourne l'oliOrderId pour le polling de statut, ou null si échec.
  Future<Map<String, dynamic>?> initiateUnipesaDeposit({
    required String phone,
    required double amountFC,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.unipesaDeposit,
        data: {
          'phone': phone,
          'amountFC': amountFC,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      }
      debugPrint('❌ Unipesa deposit error: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('❌ Erreur initiation Unipesa: $e');
      return null;
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

  /// Récupérer le tracking complet d'une commande
  Future<Map<String, dynamic>?> getTracking(int orderId) async {
    try {
      final response = await _dio.get(ApiConfig.orderTracking(orderId));
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur tracking: $e');
      return null;
    }
  }

  /// Vendeur: marquer en préparation
  Future<bool> markProcessing(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderPrepare(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur markProcessing: $e');
      return false;
    }
  }

  /// Vendeur: marquer comme prête
  Future<bool> markReady(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderReady(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur markReady: $e');
      return false;
    }
  }

  /// Livreur: valider pickup avec code
  Future<bool> verifyPickup(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderVerifyPickup(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur verifyPickup: $e');
      return false;
    }
  }

  /// Acheteur: valider livraison avec code
  Future<bool> verifyDelivery(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderVerifyDelivery(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur verifyDelivery: $e');
      return false;
    }
  }
}

/// Provider du service de commandes
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.read(dioProvider));
});

/// Provider pour récupérer le tracking d'une commande
final orderTrackingProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, orderId) async {
  final service = ref.read(orderServiceProvider);
  return service.getTracking(orderId);
});
