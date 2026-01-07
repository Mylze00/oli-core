import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

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
    required File imageFile,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Préparation de la requête "Multipart" (pour envoyer un fichier)
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Ajout des champs texte
      request.fields['name'] = name;
      request.fields['price'] = price;

      // Ajout du fichier image
      request.files.add(await http.MultipartFile.fromPath(
        'images', // Nom du champ attendu par le backend (upload.array('images'))
        imageFile.path,
      ));

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