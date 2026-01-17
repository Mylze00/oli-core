import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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
        // Optimistic Update: On suppose que l'URL sera celle retournée ou on refetch
        // Pour l'avatar, on est obligé de refetch car l'URL change (Cloudinary)
        await _ref.read(authControllerProvider.notifier).fetchUserProfile();
        state = const AsyncValue.data(null);
      } else {
        throw Exception("Échec de l'upload");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateUserName(String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty || trimmedName.length < 2) {
      state = AsyncValue.error(
        Exception("Le nom doit contenir au moins 2 caractères"),
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
        if (serverData is Map && serverData['name'] != null) {
           _ref.read(authControllerProvider.notifier).updateUserData({'name': serverData['name']});
        }
        state = const AsyncValue.data(null);
      } else {
        // Revert en cas d'erreur (idéalement)
        // Pour l'instant on throw, l'utilisateur le verra
        throw Exception("Échec de la mise à jour du nom");
      }
    } catch (e, st) {
      // En cas d'erreur, on devrait peut-être re-fetch le profil réel pour annuler l'optimistic update
      _ref.read(authControllerProvider.notifier).fetchUserProfile();
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDeliveryAddress(String address) async {
    // TODO: Implement API Endpoint for address update
    // For now, valid locally or mock
    state = const AsyncValue.data(null);
  }
}
