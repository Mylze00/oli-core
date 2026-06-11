import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/hive_cache_service.dart'; // [CACHE]

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
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userData: userData ?? this.userData,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  final _storage = SecureStorageService();

  AuthController(this._ref) : super(const AuthState()) {
    checkSession();
  }

  Dio get _dio => _ref.read(dioProvider);

  Future<void> checkSession() async {
    try {
      debugPrint("🔄 checkSession: Lecture du storage local...");
      final localData = await _storage.getUserData();
      final token = localData['token'];
      final phone = localData['phone'];
      final name = localData['name'];
      final avatarUrl = localData['avatar_url'];
      
      debugPrint("🔑 checkSession: token=${token != null ? '${token.substring(0, 10)}...(${token.length} chars)' : 'NULL'}");
      debugPrint("📱 checkSession: phone=$phone, name=$name");
      
      if (token != null && token.isNotEmpty) {
        debugPrint("✅ checkSession: Token trouvé, session restaurée !");
        state = state.copyWith(
          isAuthenticated: true,
          isCheckingSession: false, 
          userData: {
            'phone': phone ?? 'Numéro inconnu', 
            'name': name ?? (phone != null ? 'Utilisateur (${phone.substring(phone.length - 4)})' : 'Chargement...'),
            'avatar_url': avatarUrl,
          }
        );
        fetchUserProfile(); 
      } else {
        debugPrint("❌ checkSession: Pas de token — utilisateur non connecté");
        state = state.copyWith(isCheckingSession: false);
      }
    } catch (e) {
      debugPrint("❌ Erreur session : $e");
      state = state.copyWith(isCheckingSession: false);
    }
  }

  /// 🔹 RÉCUPÉRER LE PROFIL (utilise Dio avec token automatique)
  Future<void> fetchUserProfile() async {
    try {
      const cacheKey = 'user_profile_cache';
      
      // [CACHE] 1. Lecture rapide du cache
      final cachedData = HiveCacheService.getCache(cacheKey);
      if (cachedData != null && cachedData is Map<String, dynamic>) {
        final currentData = state.userData ?? {};
        final mergedAvatar = cachedData['avatar_url'] ?? currentData['avatar_url'];
        final newData = {
          ...currentData,
          ...cachedData,
          'avatar_url': mergedAvatar,
        };
        state = state.copyWith(userData: newData);
      }

      // 2. Rafraîchissement en arrière-plan
      final response = await _dio.get(ApiConfig.authMe);

      final data = response.data;
      final Map<String, dynamic>? userData = (data is Map && data.containsKey('user')) 
          ? data['user'] 
          : (data is Map ? data as Map<String, dynamic> : null);
      
      final currentData = state.userData ?? {};
      
      debugPrint("📥 Fetch Profile: Server Avatar = ${userData?['avatar_url']}");
      debugPrint("💾 Local State Avatar = ${currentData['avatar_url']}");

      final serverAvatar = userData?['avatar_url'];
      final mergedAvatar = serverAvatar ?? currentData['avatar_url'];
      
      final Map<String, dynamic> newData = {
        ...currentData,
        ...?userData,
        'avatar_url': mergedAvatar,
      };
      
      state = state.copyWith(userData: newData); 
      
      
      if (mergedAvatar != null) {
        await _storage.saveProfile(
          name: newData['name'],
          avatarUrl: mergedAvatar
        );
      }
      
      // [CACHE] 3. Mise à jour silencieuse
      if (userData != null) {
        await HiveCacheService.setCache(cacheKey, userData);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint("⚠️ Session backend expirée — profil non rafraîchi (session locale conservée).");
        // Ne PAS appeler logout() : l'utilisateur reste connecté localement
        // Il se déconnectera manuellement via le bouton Déconnexion
      }
    } catch (e) {
      debugPrint("Erreur fetchUserProfile : $e");
    }
  }

  /// sendOtp et verifyOtp utilisent http car appelés AVANT login (pas de token)
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authSendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      state = state.copyWith(isLoading: false);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final otpCode = data['otp']?.toString();
        if (otpCode != null) debugPrint('📩 OTP reçu du serveur: $otpCode');
        return true;
      }
      final data = jsonDecode(response.body);
      state = state.copyWith(isLoading: false, error: data['error'] ?? data['message'] ?? 'Erreur serveur');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Serveur injoignable');
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String otpCode}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authVerifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otpCode': otpCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken']; 
        final user = data['user'];

        if (token != null) {
          await _storage.saveSession(token, phone);
          if (user != null) {
             await _storage.saveProfile(
               name: user['name'],
               avatarUrl: user['avatar_url']
             );
          }
        }

        state = state.copyWith(
          isLoading: false, 
          isAuthenticated: true,
          userData: {
            'phone': phone, 
            'name': user?['name'] ?? 'Utilisateur (${phone.substring(phone.length - 4)})', 
            'avatar_url': user?['avatar_url']
          },
        );
        
        FcmService().init();
        fetchUserProfile(); 
        return true;
      }
      
      final data = jsonDecode(response.body);
      state = state.copyWith(isLoading: false, error: data['message'] ?? 'Code invalide');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
      return false;
    }
  }

  Future<void> logout() async {
    await FcmService().removeToken();
    await _storage.deleteAll();
    state = const AuthState(
      isAuthenticated: false, 
      isCheckingSession: false, 
      userData: null,
    );
  }

  /// 🔹 MISE À JOUR LOCALE (Optimistic UI)
  void updateUserData(Map<String, dynamic> newPartialData) {
    if (state.userData == null) return;
    
    state = state.copyWith(
      userData: {...state.userData ?? {}, ...newPartialData},
    );
    
    if (newPartialData.containsKey('name') || newPartialData.containsKey('avatar_url')) {
      final newAvatar = newPartialData['avatar_url'];
      if (newAvatar != null && newAvatar.toString().startsWith('data:')) {
         return; 
      }

      _storage.saveProfile(
        name: newPartialData['name'],
        avatarUrl: newAvatar
      );
    }
  }
}