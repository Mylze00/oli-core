import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service générique de cache offline-first utilisant Hive.
/// Permet de stocker et récupérer rapidement des réponses JSON pour
/// affichage instantané avant rafraîchissement réseau.
class HiveCacheService {
  static const String _boxName = 'oli_offline_cache';
  static Box<String>? _box;

  /// Initialise Hive et ouvre la boîte de cache. À appeler dans main().
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('✅ HiveCacheService initialisé');
  }

  /// Sauvegarde des données JSON dans le cache local.
  static Future<void> setCache(String key, dynamic data) async {
    try {
      if (_box == null) return;
      final jsonString = jsonEncode(data);
      await _box!.put(key, jsonString);
    } catch (e) {
      debugPrint('❌ Erreur HiveCacheService.setCache [$key]: $e');
    }
  }

  /// Récupère des données JSON depuis le cache local.
  static dynamic getCache(String key) {
    try {
      if (_box == null) return null;
      final jsonString = _box!.get(key);
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
    if (_box != null) {
      await _box!.delete(key);
    }
  }

  /// Efface entièrement la boîte de cache.
  static Future<void> clearAll() async {
    if (_box != null) {
      await _box!.clear();
    }
  }
}
