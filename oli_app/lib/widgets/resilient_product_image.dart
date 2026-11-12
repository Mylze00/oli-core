import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/services/oli_image_cache.dart';
import '../utils/cloudinary_helper.dart';

/// Image produit qui s'ouvre même sur une connexion faible :
/// 1. aperçu minuscule et flou affiché tout de suite (≈ 2 Ko) ;
/// 2. image réduite par Cloudinary (largeur [width], proportions conservées) ;
/// 3. si elle échoue, l'image d'origine ;
/// 4. si rien ne passe, « Toucher pour réessayer ».
/// Les images déjà vues viennent du cache.
class ResilientProductImage extends StatefulWidget {
  final String url;
  final int width;
  final BoxFit fit;
  final bool showPreview;
  final Color background;

  const ResilientProductImage({
    super.key,
    required this.url,
    this.width = 900,
    this.fit = BoxFit.contain,
    this.showPreview = true,
    this.background = Colors.white,
  });

  @override
  State<ResilientProductImage> createState() => _ResilientProductImageState();
}

class _ResilientProductImageState extends State<ResilientProductImage> {
  /// 0 : image réduite · 1 : image d'origine · 2 : échec.
  int _stage = 0;
  int _retry = 0;

  String get _optimized => CloudinaryHelper.fit(widget.url, width: widget.width);

  @override
  void didUpdateWidget(covariant ResilientProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _stage = 0;
  }

  void _onError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // Pas de version réduite distincte (image hors Cloudinary) : échec direct
        _stage = (_stage == 0 && _optimized != widget.url) ? 1 : 2;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty || _stage >= 2) return _failed();
    final source = _stage == 0 ? _optimized : widget.url;
    final preview = CloudinaryHelper.preview(widget.url);
    final hasPreview = widget.showPreview && preview != widget.url;

    return ColoredBox(
      color: widget.background,
      child: CachedNetworkImage(
        key: ValueKey('$source#$_retry'),
        imageUrl: source,
        cacheManager: OliImageCache.instance,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: widget.width,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => hasPreview
            ? CachedNetworkImage(
                imageUrl: preview,
                cacheManager: OliImageCache.instance,
                fit: widget.fit,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => const SizedBox.expand(),
                errorWidget: (_, __, ___) => const SizedBox.expand(),
              )
            : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) {
          _onError();
          return const SizedBox.expand();
        },
      ),
    );
  }

  Widget _failed() {
    return GestureDetector(
      onTap: () => setState(() {
        _stage = 0;
        _retry++;
      }),
      child: Container(
        color: const Color(0xFF2C2C2E),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white70, size: 26),
            SizedBox(height: 4),
            Text('Toucher pour réessayer', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
