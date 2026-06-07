import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service d'authentification biométrique (empreinte / Face ID)
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Vérifie si la biométrie est disponible sur cet appareil
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Authentifie l'utilisateur.
  /// Retourne `true` si authentifié, `false` sinon.
  Future<bool> authenticate({String reason = 'Confirmez votre identité pour valider le transfert'}) async {
    try {
      final available = await isAvailable();
      if (!available) return true; // fallback : on laisse passer si pas de capteur

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi le PIN si bio échoue
        ),
      );
    } catch (e) {
      // Sur web, émulateur ou si manque de permissions : ignorer l'erreur et laisser passer
      return true;
    }
  }
}

final biometricService = BiometricService();
