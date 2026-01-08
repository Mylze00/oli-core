import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'secure_storage_service.dart';

// Le fameux Provider qui manquait
final productControllerProvider = StateNotifierProvider<ProductController, AsyncValue<void>>((ref) {
  return ProductController();
});

class ProductController extends StateNotifier<AsyncValue<void>> {
  ProductController() : super(const AsyncValue.data(null));

  // Comme vous êtes sur Linux, 127.0.0.1 est votre machine locale
  final String apiUrl = '${ApiConfig.baseUrl}/products/upload';

  Future<bool> uploadProduct({
    required String name,
    required String price,
    required String description,
    required double deliveryPrice,
    required String deliveryTime,
    required String condition,
    required int quantity,
    required String color,
    required List<XFile> images,
  }) async {
    state = const AsyncValue.loading();

    try {
      final token = await SecureStorageService().getToken();
      
      // Préparation de la requête "Multipart"
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // Ajout du header d'authentification
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Ajout des champs texte
      request.fields['name'] = name;
      request.fields['price'] = price;
      request.fields['description'] = description;
      request.fields['delivery_price'] = deliveryPrice.toString();
      request.fields['delivery_time'] = deliveryTime;
      request.fields['condition'] = condition;
      request.fields['quantity'] = quantity.toString();
      request.fields['color'] = color;

      // Ajout des fichiers images
      for (var imageFile in images) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: imageFile.name,
        ));
      }

      // Envoi au serveur
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        state = const AsyncValue.data(null);
        return true;
      } else {
        state = AsyncValue.error('Erreur: ${response.statusCode}', StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error('Erreur réseau: $e', StackTrace.current);
      return false;
    }
  }
}