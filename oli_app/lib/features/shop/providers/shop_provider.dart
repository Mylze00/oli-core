import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../secure_storage_service.dart';
import '../models/shop_model.dart';

final shopControllerProvider = StateNotifierProvider<ShopController, AsyncValue<List<Shop>>>((ref) {
  return ShopController();
});

final myShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final controller = ref.watch(shopControllerProvider.notifier);
  return controller.fetchMyShops();
});

class ShopController extends StateNotifier<AsyncValue<List<Shop>>> {
  final _storage = SecureStorageService();

  ShopController() : super(const AsyncValue.loading());

  Future<List<Shop>> fetchMyShops() async {
    try {
      final token = await _storage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/shops/my-shops'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final shops = data.map((json) => Shop.fromJson(json)).toList();
        state = AsyncValue.data(shops);
        return shops;
      } else {
        throw Exception('Failed to load shops');
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<bool> createShop({
    required String name,
    required String description,
    required String category,
    String? location,
    File? logo,
    File? banner,
  }) async {
    try {
      final token = await _storage.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/shops'));
      
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['category'] = category;
      if (location != null) request.fields['location'] = location;

      if (logo != null) {
        request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
      }
      if (banner != null) {
        request.files.add(await http.MultipartFile.fromPath('banner', banner.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        // Refresh list
        await fetchMyShops();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
