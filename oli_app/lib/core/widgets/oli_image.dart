import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/oli_image_cache.dart';

/// Remplaçant direct de `Image.network` avec cache disque et nouvelles tentatives.
///
/// `Image.network` ne garde les images qu'en mémoire : elles sont
/// retéléchargées à chaque redémarrage de l'appli (lent et coûteux en
/// données mobiles), et un échec ponctuel du réseau laisse l'icône de
/// remplacement affichée pour toujours.
///
/// `OliImage.network` a **exactement la même signature** et le même rendu
/// (mêmes `errorBuilder`, `loadingBuilder`, `frameBuilder`, `cacheWidth`…), mais :
/// - lit et écrit les images dans [OliImageCache] (1 500 images, 30 jours) ;
/// - réessaie une image en échec après 2 s puis 6 s.
///
/// Le comportement d'origine est conservé tel quel :
/// - sur le web (le navigateur gère déjà son propre cache) ;
/// - pour les URL qui ne sont pas en http(s) (ex. aperçus `data:image`).
class OliImage {
  OliImage._();

  static Widget network(
    String src, {
    Key? key,
    double scale = 1.0,
    ImageFrameBuilder? frameBuilder,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    FilterQuality filterQuality = FilterQuality.medium,
    bool isAntiAlias = false,
    Map<String, String>? headers,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final bool cacheable = !kIsWeb && src.startsWith('http');
    if (!cacheable) {
      return Image.network(
        src,
        key: key,
        scale: scale,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        width: width,
        height: height,
        color: color,
        opacity: opacity,
        colorBlendMode: colorBlendMode,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
        isAntiAlias: isAntiAlias,
        headers: headers,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }

    // Même logique que Image.network : décodage réduit si cacheWidth/Height.
    ImageProvider buildProvider() => ResizeImage.resizeIfNeeded(
          cacheWidth,
          cacheHeight,
          CachedNetworkImageProvider(
            src,
            scale: scale,
            headers: headers,
            cacheManager: OliImageCache.instance,
          ),
        );

    final lowSrc = cloudinaryPreviewUrl(src);

    return _RetryingNetworkImage(
      key: key,
      buildProvider: buildProvider,
      errorBuilder: errorBuilder,
      width: width,
      height: height,
      // Aperçu flou (~1 Ko) affiché sous l'image le temps qu'elle arrive, et
      // gardé à sa place si l'image en pleine qualité n'arrive pas.
      preview: lowSrc == null
          ? null
          : Image(
              image: CachedNetworkImageProvider(lowSrc, cacheManager: OliImageCache.instance),
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: errorBuilder ??
                  (_, __, ___) => SizedBox(width: width, height: height),
            ),
      buildImage: (provider, onError) => Image(
        image: provider,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: onError,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        width: width,
        height: height,
        color: color,
        opacity: opacity,
        colorBlendMode: colorBlendMode,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
        isAntiAlias: isAntiAlias,
      ),
    );
  }

  /// Paramètres de transformation Cloudinary reconnus en tête de chemin
  /// (`w_540`, `c_fill`, `q_auto`…). Liste fermée pour ne jamais confondre avec
  /// un dossier comme `oli_app/`.
  static final RegExp _transformSegment = RegExp(
    r'^(?:(?:w|h|c|q|f|e|g|ar|dpr|fl|r|a|b|o|t|bo|co|x|y|z)_[^/,]+)(?:,(?:w|h|c|q|f|e|g|ar|dpr|fl|r|a|b|o|t|bo|co|x|y|z)_[^/,]+)*$',
  );

  /// URL d'un aperçu flou très léger (~1 Ko) d'une image Cloudinary,
  /// ou `null` si l'image n'est pas hébergée sur Cloudinary.
  static String? cloudinaryPreviewUrl(String src) {
    const marker = '/image/upload/';
    final i = src.indexOf(marker);
    if (!src.contains('res.cloudinary.com') || i < 0) return null;
    final segments = src.substring(i + marker.length).split('/');
    // Retire les transformations déjà présentes (ex. w_540,c_fill) pour partir de l'original.
    while (segments.length > 1 && _transformSegment.hasMatch(segments.first)) {
      segments.removeAt(0);
    }
    return '${src.substring(0, i)}${marker}w_60,q_40,e_blur:200,f_auto/${segments.join('/')}';
  }
}

/// Réessaie automatiquement une image dont le téléchargement a échoué.
///
/// Pendant l'attente, on affiche exactement le même `errorBuilder` qu'avant.
/// L'image est retentée après 2 s puis 6 s ; après ces 2 essais, l'icône de
/// remplacement reste affichée, comme avant.
class _RetryingNetworkImage extends StatefulWidget {
  const _RetryingNetworkImage({
    super.key,
    required this.buildProvider,
    required this.buildImage,
    required this.errorBuilder,
    this.width,
    this.height,
    this.preview,
  });

  final Widget? preview;
  final ImageProvider Function() buildProvider;
  final Widget Function(ImageProvider provider, ImageErrorWidgetBuilder onError) buildImage;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double? width;
  final double? height;

  @override
  State<_RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<_RetryingNetworkImage> {
  static const List<Duration> _delays = [Duration(seconds: 2), Duration(seconds: 6)];

  int _attempt = 0;
  bool _retryScheduled = false;

  void _scheduleRetry(ImageProvider failed) {
    if (_retryScheduled || _attempt >= _delays.length) return;
    _retryScheduled = true;
    Future.delayed(_delays[_attempt], () async {
      await failed.evict(); // oublie l'échec pour forcer un vrai nouvel essai
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  Widget _buildMain({required bool withPreview}) {
    final provider = widget.buildProvider();
    return KeyedSubtree(
      key: ValueKey(_attempt),
      child: widget.buildImage(provider, (context, error, stackTrace) {
        _scheduleRetry(provider);
        // Avec un aperçu dessous : rien par-dessus, l'aperçu flou reste visible
        // (et c'est lui qui affiche l'icône de remplacement s'il échoue aussi).
        if (withPreview) return const SizedBox.shrink();
        final original = widget.errorBuilder;
        // Sans errorBuilder, Image.network n'affiche rien à la place de l'image :
        // on garde un emplacement vide de même taille.
        return original != null
            ? original(context, error, stackTrace)
            : SizedBox(width: widget.width, height: widget.height);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    if (preview == null) return _buildMain(withPreview: false);

    final sizedByCaller = widget.width != null && widget.height != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        // L'aperçu n'est superposé que si la taille de l'image est imposée
        // (cartes, bannières…) : il ne peut alors jamais décaler la mise en page.
        final fixedSize = sizedByCaller || (constraints.hasTightWidth && constraints.hasTightHeight);
        if (!fixedSize) return _buildMain(withPreview: false);
        return Stack(
          fit: StackFit.passthrough,
          children: [preview, _buildMain(withPreview: true)],
        );
      },
    );
  }
}
