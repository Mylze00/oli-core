import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/api_config.dart';
import '../core/providers/dio_provider.dart';

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(dio: ref.watch(dioProvider));
});

class DeliveryService {
  final Dio _dio;

  DeliveryService({required Dio dio}) : _dio = dio;

  /// GET /delivery/available — Commandes en attente de prise en charge
  Future<List<dynamic>> getAvailableOrders() async {
    try {
      debugPrint('📡 Fetching available orders from: ${ApiConfig.deliveryAvailable}');
      final response = await _dio.get(ApiConfig.deliveryAvailable);
      debugPrint('✅ Response ${response.statusCode}: ${response.data?.length ?? 0} orders');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      debugPrint('⚠️ Unexpected status: ${response.statusCode}');
      return [];
    } on DioException catch (e) {
      debugPrint('❌ DioException: ${e.type} — ${e.response?.statusCode} — ${e.response?.data}');
      debugPrint('❌ Message: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching available orders: $e');
      return [];
    }
  }

  /// GET /delivery/my-tasks — Mes livraisons en cours
  Future<List<dynamic>> getMyTasks() async {
    try {
      final response = await _dio.get(ApiConfig.deliveryMyTasks);
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching my tasks: $e');
      return [];
    }
  }

  /// POST /delivery/:id/accept — Accepter une livraison
  Future<bool> acceptOrder(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.deliveryAccept(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error accepting order: $e');
      return false;
    }
  }

  /// POST /delivery/:id/status — Mettre à jour statut + position GPS
  Future<bool> updateStatus(int orderId, String status, {double? lat, double? lng}) async {
    try {
      final response = await _dio.post(
        ApiConfig.deliveryStatus(orderId),
        data: {
          'status': status,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
      return false;
    }
  }

  /// Raccourci : marquer comme livrée
  Future<bool> markAsDelivered(int orderId) async {
    return updateStatus(orderId, 'delivered');
  }

  /// POST /delivery/:id/verify — Vérifier le code QR de livraison
  Future<bool> verifyDeliveryCode(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.deliveryVerify(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error verifying delivery code: $e');
      return false;
    }
  }

  /// POST /orders/:id/verify-pickup — Vérifier le code de retrait chez le vendeur
  Future<bool> verifyPickupCode(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderVerifyPickup(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error verifying pickup code: $e');
      return false;
    }
  }

  /// GET /orders/:id/tracking — Timeline de suivi
  Future<Map<String, dynamic>?> getOrderTracking(int orderId) async {
    try {
      final response = await _dio.get(ApiConfig.orderTracking(orderId));
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching tracking: $e');
      return null;
    }
  }
}
