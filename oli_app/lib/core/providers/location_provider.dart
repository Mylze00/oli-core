import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';

final userLocationProvider = FutureProvider<String?>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return null;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );

    String coords = "${position.latitude}, ${position.longitude}";
    String locationName = await GeocodingService.coordinatesToLocationName(coords);
    
    // Si la conversion échoue et retourne les coordonnées brutes, on ignore
    if (locationName.contains('.') && !locationName.contains(RegExp(r'[a-zA-Z]'))) {
      return null;
    }

    return locationName;
  } catch (e) {
    return null;
  }
});
