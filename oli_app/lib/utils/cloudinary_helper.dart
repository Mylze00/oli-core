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

  /// Returns a card-optimized image URL — 50% quality to save data (for product cards)
  static String card(String url, {int width = 130, int height = 130}) {
    if (!url.contains('cloudinary.com')) return url;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return url;
    final afterUpload = url.substring(uploadIndex + 8);
    if (afterUpload.startsWith('c_') || afterUpload.startsWith('w_') || afterUpload.startsWith('f_')) {
      return url;
    }
    final before = url.substring(0, uploadIndex + 8);
    return '${before}c_fill,w_$width,h_$height,q_50,f_auto/$afterUpload';
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

  /// Returns a large image (for full-screen views)
  static String large(String url) {
    return thumbnail(url, width: 800, height: 800);
  }
}
