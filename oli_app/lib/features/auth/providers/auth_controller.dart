import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage/secure_storage_service.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});

class AuthState {
  final bool isLoading;
  final bool isCheckingSession; // Nouveau champ
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? userData;

  const AuthState({
    this.isLoading = false,
    this.isCheckingSession = true, // Par défaut on vérifie la session
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
  final _storage = SecureStorageService();
  final String baseUrl = ApiConfig.auth;

  AuthController() : super(const AuthState()) {
    checkSession();
  }

  Future<void> checkSession() async {
    try {
      final localData = await _storage.getUserData();
      final token = localData['token'];
      final phone = localData['phone'];
      final name = localData['name'];
      final avatarUrl = localData['avatar_url'];
      
      if (token != null && token.isNotEmpty) {
        // 1. Restaurer immédiatement l'état local (Optimistic UI)
        state = state.copyWith(
          isAuthenticated: true,
          isCheckingSession: false, 
          userData: {
            'phone': phone ?? 'Numéro inconnu', 
            'name': name ?? (phone != null ? 'Utilisateur (${phone.substring(phone.length - 4)})' : 'Chargement...'),
            'avatar_url': avatarUrl,
          }
        );
        // 2. Rafraîchir depuis le serveur
        fetchUserProfile(); 
      } else {
        // Pas de token, fin de vérification
        state = state.copyWith(isCheckingSession: false);
      }
    } catch (e) {
      debugPrint("Erreur session : $e");
      state = state.copyWith(isCheckingSession: false);
    }
  }

  /// 🔹 RÉCUPÉRER LE PROFIL (Depuis PostgreSQL)
  Future<void> fetchUserProfile() async {
    final token = await _storage.getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic>? userData = (data is Map && data.containsKey('user')) 
            ? data['user'] 
            : (data is Map ? data as Map<String, dynamic> : null);
        
        // On fusionne les nouvelles données
        final currentData = state.userData ?? {};
        
        // Log pour debug
        debugPrint("📥 Fetch Profile: Server Avatar = ${userData?['avatar_url']}");
        debugPrint("💾 Local State Avatar = ${currentData['avatar_url']}");

        // Défense: Si le serveur renvoie null pour l'avatar, on garde ce qu'on a en local (Optimistic/Storage)
        // Sauf si on explicitement veut permettre la suppression (TODO: gérer ça autrement si besoin)
        final serverAvatar = userData?['avatar_url'];
        final mergedAvatar = serverAvatar ?? currentData['avatar_url'];
        
        // Création du map fusionné avec protection
        final Map<String, dynamic> newData = {
          ...currentData,
          ...?userData,
          'avatar_url': mergedAvatar, // Force le garde
        };
        
        state = state.copyWith(userData: newData); 
        
        // 🔥 Sauvegarder uniiquement si on a une valeur valide
        if (mergedAvatar != null) {
          await _storage.saveProfile(
            name: newData['name'],
            avatarUrl: mergedAvatar
          );
        }

      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint("🔴 Session expirée ou invalide. Déconnexion automatique.");
        logout();
      }
    } catch (e) {
      debugPrint("Erreur fetchUserProfile : $e");
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      state = state.copyWith(isLoading: false);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Serveur injoignable');
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String otpCode}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
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
        
        // Pas besoin de fetchUserProfile immédiatement si on a déjà les données login
        // mais on peut le faire pour être sûr d'avoir tout (wallet, etc.)
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
    await _storage.deleteAll();
    state = const AuthState(isAuthenticated: false, userData: null);
  }

  /// 🔹 MISE À JOUR LOCALE (Optimistic UI)
  void updateUserData(Map<String, dynamic> newPartialData) {
    if (state.userData == null) return;
    
    state = state.copyWith(
      userData: {...state.userData ?? {}, ...newPartialData},
    );
    
    // Persister les changements locaux importants
    if (newPartialData.containsKey('name') || newPartialData.containsKey('avatar_url')) {
      final newAvatar = newPartialData['avatar_url'];
      // 🛡️ SÉCURITÉ : Ne jamais sauvegarder une image Base64 (trop lourd)
      // On ne sauvegarde que les "vraies" URL HTTP (Cloudinary)
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