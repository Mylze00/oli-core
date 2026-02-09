import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/api_config.dart';
import '../core/providers/dio_provider.dart';

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(dio: ref.watch(dioProvider));
});

class DeliveryService {
  final Dio _dio;

  DeliveryService({required Dio dio}) : _dio = dio;

  Future<List<dynamic>> getAvailableOrders() async {
    try {
      // Token is automatically added by Dio Interceptor
      final response = await _dio.get(ApiConfig.deliveryOrdersEndpoint);

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  Future<bool> acceptOrder(int orderId) async {
    try {
      // TODO: Implement endpoint for assigning order to driver
      // For now, we might just update status to 'processing' or 'shipped'
      final response = await _dio.patch(
        '${ApiConfig.baseUrl}/orders/$orderId/status',
        data: {'status': 'shipped'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error accepting order: $e');
      return false;
    }
  }

  Future<bool> markAsDelivered(int orderId) async {
    try {
      final response = await _dio.patch(
        '${ApiConfig.baseUrl}/orders/$orderId/status',
        data: {'status': 'delivered'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking as delivered: $e');
      return false;
    }
  }
}

