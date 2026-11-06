import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service générique de cache offline-first utilisant SharedPreferences.
/// Remplace Hive qui a été retiré des dépendances.
/// Permet de stocker et récupérer rapidement des réponses JSON pour
/// affichage instantané avant rafraîchissement réseau.
class HiveCacheService {
  static const String _prefix = 'oli_cache_';

  // Bug #8 fix: _prefs est initialisé de façon synchrone dans init() via main().
  // getCache() est sûr tant que init() a été appelé avant tout usage.
  // Si _prefs est null (race condition), on retourne null silencieusement
  // au lieu de planter, et setCache() utilisera getInstance() comme fallback.
  static SharedPreferences? _prefs;

  // Bug #8 fix: Flag pour détecter si init() a bien été appelé
  static bool _initialized = false;

  /// Initialise SharedPreferences. À appeler dans main() avant runApp().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugPrint('✅ HiveCacheService initialisé (SharedPreferences)');
  }

  /// Sauvegarde des données JSON dans le cache local.
  static Future<void> setCache(String key, dynamic data) async {
    try {
      // Bug #8 fix: Utiliser l'instance existante ou en créer une de secours
      // évite la race condition si setCache() est appelé avant init()
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (!_initialized) {
        // Mémoriser l'instance de secours pour les prochains appels getCache()
        _prefs = prefs;
        _initialized = true;
      }
      final jsonString = jsonEncode(data);
      await prefs.setString('$_prefix$key', jsonString);
    } catch (e) {
      debugPrint('❌ Erreur HiveCacheService.setCache [$key]: $e');
    }
  }

  /// Récupère des données JSON depuis le cache local.
  /// Retourne null si le cache n'est pas encore initialisé (pas de crash).
  static dynamic getCache(String key) {
    try {
      final prefs = _prefs;
      // Bug #8 fix: Si _prefs est null (race condition au démarrage),
      // retourner null proprement sans déclencher d'exception.
      if (prefs == null) {
        if (!_initialized) {
          debugPrint('⚠️ HiveCacheService.getCache [$key]: appelé avant init()');
        }
        return null;
      }
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
