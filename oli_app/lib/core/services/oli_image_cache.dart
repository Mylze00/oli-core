import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque des images produits de l'application.
///
/// Le cache par défaut de `CachedNetworkImage` ne garde que 200 images :
/// l'accueil (Top Classement, Sélection, Découverte…) et le Marché le
/// remplissent vite, les plus anciennes sont supprimées et donc
/// retéléchargées au redémarrage. Celui-ci garde 1 500 images pendant
/// 30 jours (≈ 50 à 80 Mo en 540 px).
///
/// Usage : `CachedNetworkImage(cacheManager: OliImageCache.instance, ...)`.
class OliImageCache {
  OliImageCache._();

  static const String _key = 'oliProductImages';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1500,
    ),
  );
}

/// Cache disque des vidéos des bannières du fil d'accueil.
///
/// Les vidéos sont déjà compressées par Cloudinary (720 px, sans son) : une
/// fois téléchargée, une vidéo est relue depuis le téléphone pendant 30 jours.
/// Peu d'entrées : seules quelques bannières vidéo sont actives à la fois.
class OliVideoCache {
  OliVideoCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'oliFeedVideos',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 20,
    ),
  );
}
