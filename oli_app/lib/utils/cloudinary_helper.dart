/// Utility to transform Cloudinary URLs into optimized thumbnail URLs.
/// Inserts transformation parameters (width, height, quality, format)
/// between `/upload/` and the image path to serve smaller images.
///
/// Example:
///   Input:  https://res.cloudinary.com/xxx/image/upload/v123/products/img.jpg
///   Output: https://res.cloudinary.com/xxx/image/upload/c_fill,w_200,h_200,q_auto,f_auto/v123/products/img.jpg
class CloudinaryHelper {
  /// Returns a thumbnail URL for the given image URL.
  /// [url] — the original Cloudinary image URL
  /// [width] — desired width in pixels (default: 200)
  /// [height] — desired height in pixels (default: 200)
  ///
  /// If the URL is not a Cloudinary URL, returns it as-is.
  static String thumbnail(String url, {int width = 200, int height = 200}) {
    // Only transform Cloudinary URLs
    if (!url.contains('cloudinary.com')) return url;
    
    // Already has transformations (contains c_ or w_ after /upload/)
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    
    final afterUpload = url.substring(uploadIndex + 8); // after "/upload/"
    
    // Check if transformations are already present
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    
    // Insert transformation after /upload/
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_fill,w_$width,h_$height,q_auto,f_auto/$afterUpload';
  }

  /// Returns a card-optimized image URL for product cards.
  /// 540 px (≈ 3 × 180 px logiques) et qualité q_80 : rendu net sur écrans haute densité.
  static String card(String url, {int width = 540, int height = 540}) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_fill,w_$width,h_$height,q_80,f_auto/$afterUpload';
  }

  /// Returns a medium-quality image URL (for product detail pages, etc.)
  static String medium(String url, {int width = 400, int height = 400}) {
    return thumbnail(url, width: width, height: height);
  }

  /// Returns a small thumbnail (for horizontal carousels, lists)
  static String small(String url) {
    return thumbnail(url, width: 200, height: 200);
  }

  /// Returns an extra-small thumbnail (for circles, avatars, spotlight)
  static String xsmall(String url) {
    return thumbnail(url, width: 120, height: 120);
  }

  /// Vignette « économie de données » (résultats de recherche) : 300 px, compression
  /// Cloudinary la plus économe (q_auto:eco) — environ trois fois plus légère que card().
  static String lowData(String url, {int size = 300}) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_fill,w_$size,h_$size,q_auto:eco,f_auto/$afterUpload';
  }

  /// Image redimensionnée SANS recadrage (proportions conservées), largeur max [width].
  /// Utilisée par la fiche produit : une photo de plusieurs Mo passe à ~100 Ko.
  static String fit(String url, {int width = 900}) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_limit,w_$width,q_auto,f_auto/$afterUpload';
  }

  /// Aperçu minuscule (≈ 2 Ko) affiché tout de suite, avant l'image nette.
  static String preview(String url) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_limit,w_80,q_30,e_blur:300,f_auto/$afterUpload';
  }

  /// Insère une transformation après « /upload/ » (images et vidéos Cloudinary).
  static String _transform(String url, String transformation) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_') ||
        afterUpload.startsWith('q_') || afterUpload.startsWith('so_')) {
      return url;
    }
    return '${url.substring(0, uploadIndex + 8)}$transformation/$afterUpload';
  }

  /// Image du Fil : 900 px de large au plus, proportions gardées, compression économe.
  static String feedImage(String url) => _transform(url, 'c_limit,w_900,q_auto:eco,f_auto');

  /// Vidéo du Fil : 720 px, compression économe, codec choisi selon l'appareil.
  static String feedVideo(String url) => _transform(url, 'c_limit,w_720,q_auto:eco,vc_auto');

  /// Affiche d'une vidéo (première image), en JPG léger.
  static String videoPoster(String url) {
    final poster = _transform(url, 'so_0,c_limit,w_720,q_auto:eco');
    return poster.contains('cloudinary.com') ? poster.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg') : poster;
  }

  /// Returns a large image (for full-screen views)
  static String large(String url) {
    return thumbnail(url, width: 800, height: 800);
  }
}
