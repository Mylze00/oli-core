import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service de localisation GPS pour le livreur
class LocationService {
  /// Vérifie et demande les permissions de localisation
  static Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Services de localisation désactivés');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Permission de localisation refusée');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Permission de localisation refusée définitivement');
      return false;
    }

    return true;
  }

  /// Obtient la position actuelle du livreur
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('❌ Erreur position GPS: $e');
      return null;
    }
  }

  /// Calcule la distance entre la position actuelle et une destination (en km)
  static double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }
}
