import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/api_config.dart';

class DeliveryService {
  final Dio _dio = Dio();

  Future<List<dynamic>> getAvailableOrders() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception("Non authentifié");

      final response = await _dio.get(
        ApiConfig.deliveryOrdersEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
      final token = await _getToken();
      if (token == null) return false;

      // TODO: Implement endpoint for assigning order to driver
      // For now, we might just update status to 'processing' or 'shipped'
      final response = await _dio.patch(
        '${ApiConfig.baseUrl}/orders/$orderId/status',
        data: {'status': 'shipped'}, // Or specific status
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error accepting order: $e');
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
