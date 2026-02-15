import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../config/api_config.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../../core/storage/secure_storage_service.dart';

final verificationControllerProvider = StateNotifierProvider<VerificationController, AsyncValue<void>>((ref) {
  return VerificationController(ref);
});

class VerificationController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  VerificationController(this.ref) : super(const AsyncValue.data(null));

  /// Soumettre une demande de certification avec carte d'identité
  Future<Map<String, dynamic>> submitCertificationRequest({
    required String plan,
    required String paymentMethod,
    required String documentType,
    required File idCardImage,
  }) async {
    state = const AsyncValue.loading();
    try {
      final dio = Dio();
      final storage = SecureStorageService();
      final token = await storage.getToken();

      dio.options.headers['Authorization'] = 'Bearer $token';

      // Préparer le multipart form
      final formData = FormData.fromMap({
        'plan': plan,
        'payment_method': paymentMethod,
        'document_type': documentType,
        'id_card': await MultipartFile.fromFile(
          idCardImage.path,
          filename: 'id_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/subscription/request',
        data: formData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        state = const AsyncValue.data(null);
        return {
          'success': true,
          'message': response.data['message'] ?? 'Demande envoyée !',
        };
      } else {
        throw Exception(response.data['message'] ?? "Erreur lors de la demande");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      String errorMsg = "Erreur lors de la demande";
      if (e is DioException && e.response?.data != null) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  /// Vérifier l'état de la demande en cours
  Future<Map<String, dynamic>?> checkRequestStatus() async {
    try {
      final dio = Dio();
      final storage = SecureStorageService();
      final token = await storage.getToken();

      dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await dio.get('${ApiConfig.baseUrl}/api/subscription/request/status');

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Legacy: upgrade direct (gardé pour compatibilité)
  Future<bool> upgradePlan(String plan, String paymentMethod) async {
    state = const AsyncValue.loading();
    try {
      final dio = Dio();
      final storage = SecureStorageService();
      final token = await storage.getToken();

      dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/subscription/upgrade',
        data: {
          'plan': plan,
          'paymentMethod': paymentMethod,
        },
      );

      if (response.statusCode == 200) {
        await ref.read(authControllerProvider.notifier).fetchUserProfile();
        state = const AsyncValue.data(null);
        return true;
      } else {
        throw Exception("Erreur lors de l'abonnement");
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
