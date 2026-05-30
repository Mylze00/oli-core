import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service générique de cache offline-first utilisant SharedPreferences.
/// Remplace Hive qui a été retiré des dépendances.
/// Permet de stocker et récupérer rapidement des réponses JSON pour
/// affichage instantané avant rafraîchissement réseau.
class HiveCacheService {
  static const String _prefix = 'oli_cache_';
  static SharedPreferences? _prefs;

  /// Initialise SharedPreferences. À appeler dans main().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ HiveCacheService initialisé (SharedPreferences)');
  }

  /// Sauvegarde des données JSON dans le cache local.
  static Future<void> setCache(String key, dynamic data) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('$_prefix$key', jsonString);
    } catch (e) {
      debugPrint('❌ Erreur HiveCacheService.setCache [$key]: $e');
    }
  }

  /// Récupère des données JSON depuis le cache local.
  static dynamic getCache(String key) {
    try {
      final prefs = _prefs;
      if (prefs == null) return null;
      final jsonString = prefs.getString('$_prefix$key');
      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
    } catch (e) {
      debugPrint('❌ Erreur HiveCacheService.getCache [$key]: $e');
    }
    return null;
  }

  /// Efface le cache pour une clé spécifique.
  static Future<void> clearCache(String key) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Efface entièrement le cache (toutes les clés préfixées).
  static Future<void> clearAll() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
