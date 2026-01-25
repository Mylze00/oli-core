import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../models/product_model.dart';

/// État de la recherche visuelle
class VisualSearchState {
  final bool isLoading;
  final List<Product> products;
  final Map<String, dynamic>? analysis;
  final String? error;

  VisualSearchState({
    this.isLoading = false,
    this.products = const [],
    this.analysis,
    this.error,
  });

  VisualSearchState copyWith({
    bool? isLoading,
    List<Product>? products,
    Map<String, dynamic>? analysis,
    String? error,
  }) {
    return VisualSearchState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      analysis: analysis ?? this.analysis,
      error: error,
    );
  }
}

/// Provider de recherche visuelle
class VisualSearchNotifier extends StateNotifier<VisualSearchState> {
  final Dio _dio;
  final SecureStorageService _storage;

  VisualSearchNotifier(this._dio, this._storage) : super(VisualSearchState());

  /// Rechercher des produits par image
  Future<void> searchByImage() async {
    print('🔍 [VisualSearch] Démarrage de la recherche visuelle');

    try {
      // 1. Ouvrir le sélecteur de fichiers
      state = state.copyWith(isLoading: true, error: null);

      print('   - Ouverture du sélecteur d\'images');
      
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true, // Important pour Web
        );
      } catch (pickerError) {
        print('   ❌ Erreur FilePicker: $pickerError');
        throw Exception('Impossible d\'ouvrir le sélecteur de fichiers. Veuillez réessayer.');
      }

      if (result == null) {
        print('   ℹ️ Aucune image sélectionnée (annulé)');
        state = state.copyWith(isLoading: false);
        return;
      }

      if (result.files.isEmpty || result.files.single.bytes == null) {
        print('   ⚠️ Fichier sans données');
        throw Exception('Fichier invalide. Veuillez sélectionner une image valide.');
      }

      final bytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      print('   ✅ Image sélectionnée: $fileName');
      print('   - Taille: ${bytes.length} bytes');

      // 2. Envoyer l'image au backend
      FormData formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      });

      print('   - Envoi vers: ${ApiConfig.baseUrl}/search/visual');

      final response = await _dio.post(
        '/search/visual',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('   - Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        
        print('   - Produits trouvés: ${data['productsCount']}');
        print('   - Keywords: ${data['searchTerms']}');

        // Parser les produits
        final products = (data['products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();

        state = state.copyWith(
          isLoading: false,
          products: products,
          analysis: data['analysis'],
          error: null,
        );

        print('✅ [VisualSearch] Recherche réussie - ${products.length} produits');
      } else {
        throw Exception(response.data['message'] ?? 'Erreur de recherche');
      }
    } catch (e, st) {
      print('❌ [VisualSearch] Erreur: $e');
      print('   Stack: $st');

      String errorMessage = 'Erreur lors de la recherche';
      
      if (e.toString().contains('LateInitializationError')) {
        errorMessage = 'Erreur d\'initialisation. Veuillez rafraîchir la page et réessayer.';
      } else if (e is DioException) {
        errorMessage = e.response?.data['message'] ?? e.message ?? errorMessage;
      } else if (e is Exception) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  /// Réinitialiser la recherche
  void reset() {
    state = VisualSearchState();
  }
}

/// Provider global
final visualSearchProvider = StateNotifierProvider<VisualSearchNotifier, VisualSearchState>((ref) {
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final storage = SecureStorageService();
  return VisualSearchNotifier(dio, storage);
});
