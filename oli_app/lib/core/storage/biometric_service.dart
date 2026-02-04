import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer l'authentification biométrique (Face ID / Empreinte)
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Vérifie si le dispositif supporte la biométrie
  Future<bool> isDeviceSupported() async {
    try {
      // Sur le web, la biométrie n'est pas supportée
      if (kIsWeb) return false;
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('Erreur isDeviceSupported: $e');
      return false;
    }
  }

  /// Vérifie si des biométries sont enregistrées sur l'appareil
  Future<bool> canCheckBiometrics() async {
    try {
      if (kIsWeb) return false;
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Erreur canCheckBiometrics: $e');
      return false;
    }
  }

  /// Récupère les types de biométries disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (kIsWeb) return [];
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Erreur getAvailableBiometrics: $e');
      return [];
    }
  }

  /// Vérifie si la biométrie est activée dans les préférences
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Active ou désactive la biométrie dans les préférences
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Authentifie l'utilisateur via biométrie
  /// Retourne true si authentifié, false sinon
  Future<bool> authenticate({String reason = 'Veuillez vous authentifier'}) async {
    try {
      if (kIsWeb) return false;
      
      final canAuth = await canCheckBiometrics();
      final isSupported = await isDeviceSupported();
      
      if (!canAuth || !isSupported) {
        debugPrint('Biométrie non disponible sur cet appareil');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi PIN/Pattern comme fallback
        ),
      );
    } catch (e) {
      debugPrint('Erreur authenticate: $e');
      return false;
    }
  }

  /// Vérifie et authentifie si la biométrie est activée
  /// Utilisé au démarrage de l'app pour protéger l'accès
  Future<bool> authenticateIfEnabled() async {
    final isEnabled = await isBiometricEnabled();
    if (!isEnabled) return true; // Pas activé = accès direct
    
    return await authenticate(reason: 'Connectez-vous à OLI');
  }
}
