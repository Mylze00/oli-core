import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  final _secureStorage = const FlutterSecureStorage();
  
  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'user_phone';

  // Mode dégradé si on est sur Linux (Debug) OU sur le Web (pour éviter les soucis de SecureStorage)
  bool get _useFallback => kIsWeb || (kDebugMode && defaultTargetPlatform == TargetPlatform.linux);

  /// 🔹 SAUVEGARDER
  Future<void> saveSession(String token, String phone) async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_phoneKey, phone);
      debugPrint("💾 [Mode Dégradé] Session sauvegardée (Prefs)");
    } else {
      try {
        await _secureStorage.write(key: _tokenKey, value: token);
        await _secureStorage.write(key: _phoneKey, value: phone);
      } catch (e) {
        debugPrint("❌ Erreur SecureStorage Write: $e");
      }
    }
  }

  /// 🔹 RÉCUPÉRER TOKEN
  Future<String?> getToken() async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// 🔹 RÉCUPÉRER TÉLÉPHONE
  Future<String?> getPhone() async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey);
    }
    try {
      return await _secureStorage.read(key: _phoneKey);
    } catch (e) {
      return null;
    }
  }

  /// 🔹 TOUT SUPPRIMER (Logout)
  Future<void> deleteAll() async {
    if (_useFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_phoneKey);
    }
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint("❌ Erreur SecureStorage Delete: $e");
    }
  }
}