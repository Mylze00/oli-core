import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/oli_image_cache.dart';
import '../providers/feed_banners_provider.dart';

/// Bannière du fil d'accueil (entre deux blocs du Top Classement).
///
/// - Image : gardée en cache disque ([OliImageCache]).
/// - Vidéo : téléchargée une fois puis relue depuis le téléphone
///   ([OliVideoCache]) ; lue sans son, en boucle, seulement quand elle est
///   visible. La vignette s'affiche pendant le chargement.
/// - Toucher : ouvre le lien de la bannière s'il y en a un.
///
/// Même écart (10 px) et même arrondi (6 px) que les cartes produits.
class FeedBannerTile extends StatelessWidget {
  final FeedBanner banner;

  const FeedBannerTile({super.key, required this.banner});

  Future<void> _openLink() async {
    final uri = Uri.tryParse(banner.linkUrl ?? '');
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erreur ouverture lien bannière: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le bloc suivant ajoute déjà 8 px en haut, d'où les 2 px en bas.
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: GestureDetector(
        onTap: banner.linkUrl == null ? null : _openLink,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: banner.isVideo
              ? _FeedBannerVideo(banner: banner)
              : _CachedBannerImage(url: banner.mediaUrl),
        ),
      ),
    );
  }
}

/// Image pleine largeur à son format d'origine, depuis le cache disque.
class _CachedBannerImage extends StatelessWidget {
  final String url;

  const _CachedBannerImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = AspectRatio(
      aspectRatio: 3,
      child: Container(color: Colors.grey[900]),
    );
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: OliImageCache.instance,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class _FeedBannerVideo extends StatefulWidget {
  final FeedBanner banner;

  const _FeedBannerVideo({required this.banner});

  @override
  State<_FeedBannerVideo> createState() => _FeedBannerVideoState();
}

class _FeedBannerVideoState extends State<_FeedBannerVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  ScrollPosition? _scrollPosition;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// Mobile : vidéo lue depuis le cache disque (téléchargée une seule fois).
  /// Web : pas de fichiers locaux, le cache du navigateur prend le relais.
  Future<void> _load() async {
    final url = widget.banner.mediaUrl;
    try {
      final VideoPlayerController controller;
      if (kIsWeb) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        final file = await OliVideoCache.instance.getSingleFile(url);
        controller = VideoPlayerController.file(file);
      }
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _updatePlayback();
    } catch (e) {
      // La vignette reste affichée.
      debugPrint('⚠️ Vidéo de bannière indisponible: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lecture/pause selon le défilement de la page d'accueil.
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_updatePlayback);
      _scrollPosition = position?..addListener(_updatePlayback);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_updatePlayback);
    _controller?.dispose();
    super.dispose();
  }

  /// Vrai si l'app est au premier plan, l'onglet affiché et la vidéo
  /// au moins à moitié à l'écran.
  bool _isVisible() {
    if (!mounted || !_appActive || !TickerMode.getNotifier(context).value) {
      return false;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    final height = box.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final visible = (top + height).clamp(0, screenHeight) - top.clamp(0, screenHeight);
    return visible >= height / 2;
  }

  void _updatePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final shouldPlay = _isVisible();
    if (shouldPlay && !controller.value.isPlaying) {
      controller.play();
    } else if (!shouldPlay && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      );
    }
    final poster = widget.banner.posterUrl;
    if (poster != null) return _CachedBannerImage(url: poster);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(color: Colors.grey[900]),
    );
  }
}
