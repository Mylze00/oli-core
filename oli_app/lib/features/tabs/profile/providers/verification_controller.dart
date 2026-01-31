import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../config/api_config.dart';
import '../../../../main.dart'; // Pour acceder au provider global si besoin ou Dio
import '../../../auth/providers/auth_controller.dart';

final verificationControllerProvider = StateNotifierProvider<VerificationController, AsyncValue<void>>((ref) {
  return VerificationController(ref);
});

class VerificationController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  VerificationController(this.ref) : super(const AsyncValue.data(null));

  Future<bool> upgradePlan(String plan, String paymentMethod) async {
    state = const AsyncValue.loading();
    try {
      final dio = Dio(); // Ou utiliser une instance Dio configurée globalement avec intercepteurs token
      final token = await ref.read(secureStorageProvider).read(key: 'auth_token');
      
      dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/subscription/upgrade',
        data: {
          'plan': plan, // 'certified', 'enterprise'
          'paymentMethod': paymentMethod, // 'orange_money', 'mtn', 'card'
        },
      );

      if (response.statusCode == 200) {
        // Rafraichir le profil utilisateur pour voir le badge immédiatement
        await ref.read(authControllerProvider.notifier).refreshUser();
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
