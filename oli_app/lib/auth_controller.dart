import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? userData; // Pour stocker les infos PostgreSQL

  const AuthState({
    this.isLoading = false, 
    this.error, 
    this.isAuthenticated = false,
    this.userData,
  });

  AuthState copyWith({
    bool? isLoading, 
    String? error, 
    bool? isAuthenticated,
    Map<String, dynamic>? userData,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
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
      final token = await _storage.getToken();
      final phone = await _storage.getPhone(); 
      
      if (token != null) {
        // ✅ CORRECTION FLICKER : On met immédiatement le vrai numéro si dispo
        state = state.copyWith(
          isAuthenticated: true,
          userData: {
            'phone': phone ?? 'Numéro inconnu', 
            'name': phone != null ? 'Utilisateur (${phone.substring(phone.length - 4)})' : 'Chargement...'
          }
        );
        // On lance le fetch en arrière-plan pour compléter (avatar, nom complet...)
        fetchUserProfile(); 
      }
    } catch (e) {
      debugPrint("Erreur session : $e");
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
        
        // On fusionne les nouvelles données (nom, email) avec le téléphone déjà présent
        final currentData = state.userData ?? {};
        state = state.copyWith(
          userData: {...currentData, ...?userData}
        ); 
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token invalide ou expiré -> Déconnexion
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
        final token = data['token'] ?? data['accessToken']; // Robustesse
        if (token != null) {
          await _storage.saveSession(token, phone);
        }

        // --- MODIFICATION ICI : On injecte le numéro de téléphone immédiatement ---
        state = state.copyWith(
          isLoading: false, 
          isAuthenticated: true,
          userData: {
            'phone': phone, 
            'name': 'Utilisateur (${phone.substring(phone.length - 4)})', 
          },
        );
        
        await fetchUserProfile(); // Puis on complète avec PostgreSQL
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
}