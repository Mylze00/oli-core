import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/delivery_order_model.dart';

/// Provider pour le service de livraison
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(ref.read(dioProvider));
});

class DeliveryService {
  final Dio _dio;

  DeliveryService(this._dio);

  // Commandes disponibles
  Future<List<DeliveryOrder>> getAvailableDeliveries() async {
    try {
      final response = await _dio.get(ApiConfig.deliveryAvailable);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => DeliveryOrder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load available deliveries');
      }
    } on DioException catch (e) {
      debugPrint('❌ Erreur getAvailableDeliveries: ${e.message}');
      rethrow;
    }
  }

  // Mes livraisons
  Future<List<DeliveryOrder>> getMyTasks() async {
    try {
      final response = await _dio.get(ApiConfig.deliveryMyTasks);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => DeliveryOrder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load my tasks');
      }
    } on DioException catch (e) {
      debugPrint('❌ Erreur getMyTasks: ${e.message}');
      rethrow;
    }
  }

  // Accepter une livraison
  Future<DeliveryOrder> acceptDelivery(int id) async {
    try {
      final response = await _dio.post(ApiConfig.deliveryAccept(id));

      if (response.statusCode == 200) {
        return DeliveryOrder.fromJson(response.data['delivery']);
      } else {
        throw Exception('Failed to accept delivery');
      }
    } on DioException catch (e) {
      debugPrint('❌ Erreur acceptDelivery: ${e.message}');
      rethrow;
    }
  }

  // Mettre à jour le statut
  Future<DeliveryOrder> updateStatus(int id, String status, {double? lat, double? lng}) async {
    try {
      final response = await _dio.post(
        ApiConfig.deliveryStatus(id),
        data: {
          'status': status,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );

      if (response.statusCode == 200) {
        return DeliveryOrder.fromJson(response.data['delivery']);
      } else {
        throw Exception('Failed to update status');
      }
    } on DioException catch (e) {
      debugPrint('❌ Erreur updateStatus: ${e.message}');
      rethrow;
    }
  }
}
