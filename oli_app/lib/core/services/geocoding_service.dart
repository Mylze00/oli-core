import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service pour convertir les coordonnées GPS en noms de lieux lisibles
class GeocodingService {
  // Cache pour éviter les appels répétés
  static final Map<String, String> _cache = {};
  
  /// Convertit des coordonnées GPS en nom de lieu
  /// Exemple: "-4.3462, 15.2155" → "Kinshasa, Gombe"
  static Future<String> coordinatesToLocationName(String? coordinates) async {
    // Si pas de coordonnées, retourner par défaut
    if (coordinates == null || coordinates.trim().isEmpty) {
      return "Non spécifié";
    }
    
    // Si ce n'est pas des coordonnées GPS (pas de virgule ou point), retourner tel quel
    if (!coordinates.contains(',') && !coordinates.contains('.')) {
      return coordinates;
    }
    
    // Vérifier le cache
    if (_cache.containsKey(coordinates)) {
      return _cache[coordinates]!;
    }
    
    try {
      // Parser les coordonnées
      final parts = coordinates.split(',').map((e) => e.trim()).toList();
      if (parts.length != 2) {
        return coordinates; // Format invalide, retourner tel quel
      }
      
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      
      if (lat == null || lon == null) {
        return coordinates; // Pas des nombres valides
      }
      
      // Appel API Nominatim (OpenStreetMap - gratuit et sans clé)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$lat&lon=$lon&format=json&accept-language=fr'
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OliApp/1.0'}, // Requis par Nominatim
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        
        // Extraire les informations pertinentes
        String locationName = '';
        
        // Priorité : quartier > ville > province > pays
        if (address['suburb'] != null) {
          locationName = address['suburb'];
        } else if (address['neighbourhood'] != null) {
          locationName = address['neighbourhood'];
        } else if (address['village'] != null) {
          locationName = address['village'];
        }
        
        // Ajouter la ville si disponible
        if (address['city'] != null) {
          if (locationName.isNotEmpty) {
            locationName += ', ${address['city']}';
          } else {
            locationName = address['city'];
          }
        } else if (address['town'] != null) {
          if (locationName.isNotEmpty) {
            locationName += ', ${address['town']}';
          } else {
            locationName = address['town'];
          }
        }
        
        // Si toujours vide, utiliser le display_name complet
        if (locationName.isEmpty && data['display_name'] != null) {
          // Prendre les 2 premiers éléments du display_name
          final parts = (data['display_name'] as String).split(',');
          locationName = parts.take(2).join(',').trim();
        }
        
        // Sauvegarder dans le cache
        if (locationName.isNotEmpty) {
          _cache[coordinates] = locationName;
          return locationName;
        }
      }
      
      // En cas d'échec, retourner les coordonnées formatées
      return coordinates;
      
    } catch (e) {
      // En cas d'erreur (timeout, réseau, etc.), retourner les coordonnées
      return coordinates;
    }
  }
  
  /// Nettoie le cache (utile pour les tests ou libérer la mémoire)
  static void clearCache() {
    _cache.clear();
  }
}
