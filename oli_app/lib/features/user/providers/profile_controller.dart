import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../config/api_config.dart';

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  return ProfileController(ref);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProfileController(this._ref) : super(const AsyncValue.data(null));

  Dio get _dio => _ref.read(dioProvider);

  /// Sélectionne une image depuis la galerie (compatible Web)
  Future<Map<String, dynamic>?> pickAvatarImage() async {
    try {
      debugPrint("🎯 [ProfileController] Ouverture du sélecteur de fichiers");
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        
        debugPrint("✅ Image sélectionnée: $name (${bytes.length} bytes)");
        
        return {
          'bytes': bytes,
          'name': name,
        };
      }
      
      return null;
    } catch (e) {
      debugPrint("❌ Erreur sélection image: $e");
      return null;
    }
  }

  /// Upload l'avatar vers le backend
  Future<void> uploadAvatarImage(Uint8List bytes, String fileName) async {
    // 📸 Prévisualisation immédiate avec l'image locale
    try {
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _ref.read(authControllerProvider.notifier).updateUserData({'avatar_url': base64Image});
    } catch (e) {
      debugPrint("⚠️ Erreur prévisualisation image: $e");
    }

    state = const AsyncValue.loading();

    try {
      FormData formData = FormData.fromMap({
        "avatar": MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post(
        ApiConfig.authUploadAvatar,
        data: formData,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        String? newAvatarUrl;
        if (responseData is Map && responseData['avatarUrl'] != null) {
          newAvatarUrl = responseData['avatarUrl'];
        } else if (responseData is Map && responseData['avatar_url'] != null) {
          newAvatarUrl = responseData['avatar_url'];
        }
        
        if (newAvatarUrl != null) {
          final cacheBustedUrl = newAvatarUrl.contains('?') 
              ? '$newAvatarUrl&t=${DateTime.now().millisecondsSinceEpoch}'
              : '$newAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          
          // Eviction du cache image
          try {
             final authState = _ref.read(authControllerProvider);
             if (authState.userData != null && authState.userData!['avatar_url'] != null) {
               final oldUrl = authState.userData!['avatar_url'];
               if (!oldUrl.startsWith('data:image')) {
                 final imageProvider = NetworkImage(oldUrl.startsWith('http') ? oldUrl : '${ApiConfig.baseUrl}/$oldUrl');
                 PaintingBinding.instance.imageCache.evict(imageProvider);
               }
             }
          } catch (e) {
             debugPrint("Cache eviction error: $e");
          }

          _ref.read(authControllerProvider.notifier).updateUserData({'avatar_url': cacheBustedUrl});
        }
        
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
      debugPrint("❌ Upload avatar error: $message");
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
      // Optimistic Update
      _ref.read(authControllerProvider.notifier).updateUserData({'name': trimmedName});

      final response = await _dio.put(
        ApiConfig.userUpdateName,
        data: {'name': trimmedName},
      );

      if (response.statusCode == 200) {
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
    state = const AsyncValue.data(null);
  }
}
