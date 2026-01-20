import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/painting.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../config/api_config.dart';

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController(ref);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final _storage = SecureStorageService();
  final Dio _dio = Dio(); // Should ideally come from a provider

  ProfileController(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // 📸 Prévisualisation immédiate avec l'image locale
    try {
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      // Mise à jour optimiste IMMÉDIATE avec l'image locale
      _ref.read(authControllerProvider.notifier).updateUserData({'avatar_url': base64Image});
    } catch (e) {
      print("⚠️ Erreur prévisualisation image: $e");
    }

    state = const AsyncValue.loading();

    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception("Non authentifié");

      String fileName = image.path.split('/').last;
      FormData formData = FormData.fromMap({
        "avatar": await MultipartFile.fromFile(image.path, filename: fileName),
      });

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/auth/upload-avatar',
        data: formData,
        options: Options(headers: {
          "Authorization": "Bearer $token",
        }),
      );

      if (response.statusCode == 200) {
        // Extraire la nouvelle URL d'avatar depuis la réponse
        final responseData = response.data;
        String? newAvatarUrl;
        if (responseData is Map && responseData['avatarUrl'] != null) {
          newAvatarUrl = responseData['avatarUrl'];
        } else if (responseData is Map && responseData['avatar_url'] != null) {
          newAvatarUrl = responseData['avatar_url'];
        }
        
        // Mise à jour optimiste immédiate si on a l'URL
        if (newAvatarUrl != null) {
          // Ajouter un timestamp pour forcer le cache à se rafraîchir
          final cacheBustedUrl = newAvatarUrl.contains('?') 
              ? '$newAvatarUrl&t=${DateTime.now().millisecondsSinceEpoch}'
              : '$newAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          
          print("🔄 Updating Avatar State with: $cacheBustedUrl");
          
          // FORCER L'EVICTION DU CACHE IMAGE
          try {
             final authState = _ref.read(authControllerProvider);
             if (authState.userData != null && authState.userData!['avatar_url'] != null) {
               final oldUrl = authState.userData!['avatar_url'];
               // Ne pas éviter le cache de l'image base64 temporaire
               if (!oldUrl.startsWith('data:image')) {
                 final imageProvider = NetworkImage(oldUrl.startsWith('http') ? oldUrl : '${ApiConfig.baseUrl}/$oldUrl');
                 PaintingBinding.instance.imageCache.evict(imageProvider);
               }
             }
          } catch (e) {
             print("Cache eviction error: $e");
          }

          _ref.read(authControllerProvider.notifier).updateUserData({'avatar_url': cacheBustedUrl});
        }
        
        // Refetch pour synchroniser avec la base de données
        await _ref.read(authControllerProvider.notifier).fetchUserProfile();
        state = const AsyncValue.data(null);
      } else {
        final errorMsg = response.data is Map ? response.data['error'] : "Échec de l'upload";
        throw Exception(errorMsg);
      }
    } catch (e, st) {
      String message = e.toString();
      if (e is DioException && e.response?.data != null) {
        message = e.response?.data['error'] ?? message;
      }
      state = AsyncValue.error(message, st);
    }
  }

  Future<void> updateUserName(String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty || trimmedName.length < 2) {
      state = AsyncValue.error(
        "Le nom doit contenir au moins 2 caractères",
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception("Non authentifié");

      // 1. Optimistic Update (Immédiat)
      _ref.read(authControllerProvider.notifier).updateUserData({'name': trimmedName});

      final response = await _dio.put(
        '${ApiConfig.baseUrl}/user/update-name',
        data: {'name': trimmedName},
        options: Options(headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        }),
      );

      if (response.statusCode == 200) {
        // Confirmation (Optionnel, au cas où le serveur a normalisé le nom)
        final serverData = response.data;
        if (serverData is Map && serverData['user'] != null && serverData['user']['name'] != null) {
           _ref.read(authControllerProvider.notifier).updateUserData({'name': serverData['user']['name']});
        }
        state = const AsyncValue.data(null);
      } else {
        final errorMsg = response.data is Map ? response.data['error'] : "Échec de la mise à jour";
        throw Exception(errorMsg);
      }
    } catch (e, st) {
      // Re-fetch le profil réel pour annuler l'optimistic update en cas d'erreur
      _ref.read(authControllerProvider.notifier).fetchUserProfile();
      
      String message = e.toString();
      if (e is DioException && e.response?.data != null) {
        message = e.response?.data['error'] ?? message;
      }
      state = AsyncValue.error(message, st);
    }
  }

  Future<void> updateDeliveryAddress(String address) async {
    // TODO: Implement API Endpoint for address update
    // For now, valid locally or mock
    state = const AsyncValue.data(null);
  }
}
