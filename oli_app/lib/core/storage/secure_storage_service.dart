import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider Riverpod pour SecureStorageService
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final _secureStorage = const FlutterSecureStorage();
  
  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'user_phone';

  static const _nameKey = 'user_name';
  static const _avatarKey = 'user_avatar';

  // Mode dégradé si on est sur Linux (Debug) OU sur le Web (pour éviter les soucis de SecureStorage)
  bool get _useFallback => kIsWeb || (kDebugMode && defaultTargetPlatform == TargetPlatform.linux);

  /// 🔹 SAUVEGARDER SESSION (Token + Phone)
  Future<void> saveSession(String token, String phone) async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_phoneKey, phone);
    } else {
      try {
        await _secureStorage.write(key: _tokenKey, value: token);
        await _secureStorage.write(key: _phoneKey, value: phone);
      } catch (e) {
        debugPrint("❌ Erreur SecureStorage Write Session: $e");
      }
    }
  }

  /// 🔹 SAUVEGARDER PROFIL LOCAL (Nom + Avatar)
  Future<void> saveProfile({String? name, String? avatarUrl}) async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) await prefs.setString(_nameKey, name);
      if (avatarUrl != null) await prefs.setString(_avatarKey, avatarUrl);
    } else {
      try {
        if (name != null) await _secureStorage.write(key: _nameKey, value: name);
        if (avatarUrl != null) await _secureStorage.write(key: _avatarKey, value: avatarUrl);
      } catch (e) {
        debugPrint("❌ Erreur SecureStorage Write Profile: $e");
      }
    }
  }

  /// 🔹 RÉCUPÉRER DONNÉES UTILISATEUR COMPLÈTES
  Future<Map<String, String?>> getUserData() async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString(_tokenKey);
      if (token != null) token = token.replaceAll('"', '');
      
      return {
        'token': token,
        'phone': prefs.getString(_phoneKey),
        'name': prefs.getString(_nameKey),
        'avatar_url': prefs.getString(_avatarKey),
      };
    }
    try {
      return {
        'token': await _secureStorage.read(key: _tokenKey),
        'phone': await _secureStorage.read(key: _phoneKey),
        'name': await _secureStorage.read(key: _nameKey),
        'avatar_url': await _secureStorage.read(key: _avatarKey),
      };
    } catch (e) {
      return {};
    }
  }

  /// 🔹 RÉCUPÉRER TOKEN (Legacy access)
  Future<String?> getToken() async {
    final data = await getUserData();
    return data['token'];
  }

  /// 🔹 RÉCUPÉRER TÉLÉPHONE (Legacy access)
  Future<String?> getPhone() async {
    final data = await getUserData();
    return data['phone'];
  }

  /// 🔹 TOUT SUPPRIMER (Logout)
  Future<void> deleteAll() async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_phoneKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_avatarKey);
    }
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint("❌ Erreur SecureStorage Delete: $e");
    }
  }
}