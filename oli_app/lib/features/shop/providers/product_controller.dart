import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';

final productControllerProvider = StateNotifierProvider<ProductController, AsyncValue<void>>((ref) {
  return ProductController();
});

class ProductController extends StateNotifier<AsyncValue<void>> {
  ProductController() : super(const AsyncValue.data(null));

  final Dio _dio = Dio();
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
    String? category, // Nouvelle catégorie optionnelle
    String? location,
  }) async {
    state = const AsyncValue.loading();

    try {
      final token = await SecureStorageService().getToken();
      debugPrint("🚀 [DIAG] Début upload. Token trouvé: ${token != null}");
      
      if (token == null || token.isEmpty) {
        debugPrint("❌ [DIAG] Erreur: Token absent. Annulation.");
        state = AsyncValue.error('Session expirée. Veuillez vous reconnecter.', StackTrace.current);
        return false;
      }

      // Préparation des fichiers
      List<MultipartFile> multipartFiles = [];
      for (var file in images) {
        final bytes = await file.readAsBytes();
        multipartFiles.add(MultipartFile.fromBytes(bytes, filename: file.name));
      }

      // Création du FormData (plus robuste pour le Web)
      FormData formData = FormData.fromMap({
        'name': name,
        'price': price,
        'description': description,
        'delivery_price': deliveryPrice,
        'delivery_time': deliveryTime,
        'condition': condition,
        'quantity': quantity,
        'color': color,
        'category': category ?? 'Autres', // Catégorie avec valeur par défaut
        'location': location,
        'images': multipartFiles,
      });

      debugPrint("📡 [DIAG] Envoi via Dio à $apiUrl");
      debugPrint("🔑 [DIAG] Header Auth: Bearer ${token.substring(0, 5)}...");

      final response = await _dio.post(
        apiUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true, // On gère nous-mêmes les erreurs
        ),
      );

      debugPrint("📥 [DIAG] Réponse serveur (${response.statusCode}): ${response.data}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("✅ [DIAG] Succès !");
        state = const AsyncValue.data(null);
        return true;
      } else {
        debugPrint("❌ [DIAG] Échec Serveur: ${response.data}");
        state = AsyncValue.error('Erreur: ${response.statusCode}', StackTrace.current);
        return false;
      }
    } catch (e) {
      debugPrint("❌ [DIAG] Erreur Exception: $e");
      state = AsyncValue.error('Erreur réseau: $e', StackTrace.current);
      return false;
    }
  }
}
