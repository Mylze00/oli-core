import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/storage_provider.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthState {
  final bool isLoading;
  final bool isCheckingSession;
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? userData;

  const AuthState({
    this.isLoading = false,
    this.isCheckingSession = true,
    this.error,
    this.isAuthenticated = false,
    this.userData,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isCheckingSession,
    String? error,
    bool? isAuthenticated,
    Map<String, dynamic>? userData,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingSession: isCheckingSession ?? this.isCheckingSession,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userData: userData ?? this.userData,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(const AuthState()) {
    checkSession();
  }

  Future<void> checkSession() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        state = state.copyWith(isCheckingSession: false);
        return;
      }

      // Valider le token en appelant /auth/me
      final dio = _ref.read(dioProvider);
      final response = await dio.get(ApiConfig.meEndpoint);

      if (response.statusCode == 200) {
        final user = response.data['user'];

        // Vérifier que l'utilisateur est bien un livreur
        if (user == null || user['is_deliverer'] != true) {
          await _clearCredentials();
          state = state.copyWith(
            isCheckingSession: false,
            error: 'Accès réservé aux livreurs',
          );
          return;
        }

        await storage.write(key: 'user_phone', value: user['phone'] ?? '');
        state = state.copyWith(
          isAuthenticated: true,
          isCheckingSession: false,
          userData: {
            'phone': user['phone'] ?? 'Livreur',
            'name': user['name'] ?? 'Livreur',
            'is_deliverer': true,
          },
        );
      } else {
        await _clearCredentials();
        state = state.copyWith(isCheckingSession: false);
      }
    } on DioException catch (e) {
      // Token expiré ou invalide → nettoyer
      if (e.response?.statusCode == 401) {
        await _clearCredentials();
      }
      state = state.copyWith(isCheckingSession: false);
    } catch (e) {
      print('Erreur session: $e');
      state = state.copyWith(isCheckingSession: false);
    }
  }

  Future<void> _clearCredentials() async {
    final storage = _ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_phone');
    await storage.delete(key: 'user_data');
  }

  Future<bool> sendOtp(String phone) async {
    print('🔵 [AUTH] sendOtp called for: $phone');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      print('🔵 [AUTH] Calling: ${ApiConfig.sendOtpEndpoint}');
      
      final response = await dio.post(
        ApiConfig.sendOtpEndpoint,
        data: {'phone': phone},
      );
      
      print('🔵 [AUTH] Response status: ${response.statusCode}');
      print('🔵 [AUTH] Response data: ${response.data}');
      
      state = state.copyWith(isLoading: false);
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('❌ [AUTH] DioException: ${e.message}');
      print('❌ [AUTH] Response: ${e.response?.data}');
      print('❌ [AUTH] Status code: ${e.response?.statusCode}');
      
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Serveur injoignable',
      );
      return false;
    } catch (e) {
      print('❌ [AUTH] Erreur generale: $e');
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String otpCode}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      final storage = _ref.read(secureStorageProvider);

      final response = await dio.post(
        ApiConfig.verifyOtpEndpoint,
        data: {'phone': phone, 'otpCode': otpCode},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'] ?? data['accessToken'];
        
        // ✨ VÉRIFICATION: L'utilisateur doit être un livreur
        final user = data['user'];
        if (user == null || user['is_deliverer'] != true) {
          state = state.copyWith(
            isLoading: false,
            error: 'Accès réservé aux livreurs. Veuillez contacter l\'administrateur.',
          );
          return false;
        }

        if (token != null) {
          await storage.write(key: 'auth_token', value: token);
          await storage.write(key: 'user_phone', value: phone);
          await storage.write(key: 'user_data', value: user.toString());
        }

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userData: {
            'phone': phone,
            'is_deliverer': true,
            'name': user['name'] ?? 'Livreur',
          },
        );
        return true;
      }

      final errorMsg = response.data?['message'] ?? 'Code invalide';
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Code invalide',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
      return false;
    }
  }

  Future<void> logout() async {
    final storage = _ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_phone');
    state = const AuthState(isAuthenticated: false, isCheckingSession: false, userData: null);
  }
}
