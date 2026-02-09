import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/shop_model.dart';

final shopControllerProvider = StateNotifierProvider<ShopController, AsyncValue<List<Shop>>>((ref) {
  return ShopController(ref);
});

final myShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final controller = ref.watch(shopControllerProvider.notifier);
  return controller.fetchMyShops();
});

class ShopController extends StateNotifier<AsyncValue<List<Shop>>> {
  final Ref _ref;

  ShopController(this._ref) : super(const AsyncValue.loading());

  Dio get _dio => _ref.read(dioProvider);

  Future<List<Shop>> fetchMyShops() async {
    try {
      final response = await _dio.get('${ApiConfig.shops}/my-shops');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
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

  /// NOTE: createShop utilise encore http.MultipartRequest car Dio FormData
  /// nécessite une migration plus complexe pour les fichiers.
  Future<bool> createShop({
    required String name,
    required String description,
    required String category,
    String? location,
    XFile? logo,
    XFile? banner,
  }) async {
    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.getToken();
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.shops));
      
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['category'] = category;
      if (location != null) request.fields['location'] = location;

      if (logo != null) {
        final bytes = await logo.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'logo', 
          bytes, 
          filename: logo.name
        ));
      }
      if (banner != null) {
        final bytes = await banner.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'banner', 
          bytes,
          filename: banner.name
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        await fetchMyShops();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur création shop: $e');
      return false;
    }
  }
}
