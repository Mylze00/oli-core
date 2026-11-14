import 'package:oli_app/core/widgets/oli_image.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/oli_surface.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../models/feed_model.dart';
import '../../providers/feed_provider.dart';

/// Média d'un post, affiché EN ENTIER : toute la largeur, hauteur naturelle (aucun
/// recadrage), à partir de versions compressées par Cloudinary pour un aperçu rapide.
/// Les vidéos se lancent seules, en muet, quand elles sont bien visibles (réglage
/// « Lecture automatique ») ; un toucher active ou coupe le son.
class FeedMedia extends StatelessWidget {
  final FeedPost post;

  /// Aperçu figé (menu contextuel) : jamais de lecture vidéo.
  final bool still;
  final double radius;

  const FeedMedia({super.key, required this.post, this.still = false, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final url = post.mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: post.mediaType == 'video'
          ? (still ? _Poster(url: url, showPlay: true) : _FeedVideo(url: url))
          : _FullWidthImage(url: CloudinaryHelper.feedImage(url)),
    );
  }
}

/// Image sur toute la largeur, hauteur selon ses proportions.
class _FullWidthImage extends StatelessWidget {
  final String url;
  const _FullWidthImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    return OliImage.network(
      url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              height: 220,
              color: s.tile,
              alignment: Alignment.center,
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: s.accent)),
            ),
      errorBuilder: (_, __, ___) => Container(
        height: 180,
        color: s.tile,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, size: 40, color: s.textSecondary),
      ),
    );
  }
}

/// Affiche de la vidéo (première image), sur toute la largeur.
class _Poster extends StatelessWidget {
  final String url;
  final bool showPlay;
  const _Poster({required this.url, required this.showPlay});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _FullWidthImage(url: CloudinaryHelper.videoPoster(url)),
        if (showPlay)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
      ],
    );
  }
}

class _FeedVideo extends ConsumerStatefulWidget {
  final String url;
  const _FeedVideo({required this.url});

  @override
  ConsumerState<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends ConsumerState<_FeedVideo> {
  VideoPlayerController? _controller;
  ScrollPosition? _position;
  bool _visible = false;
  bool _muted = true;
  bool _userStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_checkVisibility);
      _position = position;
      _position?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    _controller?.dispose();
    super.dispose();
  }

  /// Part de la vidéo visible à l'écran : au-delà de 60 %, elle joue ; sinon pause.
  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.height == 0) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.of(context).size.height;
    final shown = math.min(top + box.size.height, screen) - math.max(top, 0);
    final visible = shown / box.size.height > 0.6;
    if (visible == _visible) return;
    _visible = visible;
    _apply();
  }

  Future<void> _apply() async {
    final autoplay = ref.read(feedAutoplayProvider);
    final shouldPlay = _visible && (autoplay || _userStarted);
    if (shouldPlay) {
      await _ensureController();
      if (mounted && _visible) _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(CloudinaryHelper.feedVideo(widget.url)));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (mounted) setState(() {});
    } catch (_) {
      // Lecture impossible : l'affiche reste visible
    }
  }

  void _onTap() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      // Lecture automatique désactivée : le toucher lance la vidéo
      _userStarted = true;
      _visible = true;
      _apply();
      return;
    }
    setState(() => _muted = !_muted);
    controller.setVolume(_muted ? 0 : 1);
    if (!controller.value.isPlaying) controller.play();
  }

  @override
  Widget build(BuildContext context) {
    // Le réglage change : on applique tout de suite (lecture ou pause)
    ref.listen<bool>(feedAutoplayProvider, (_, __) => _apply());
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final autoplay = ref.watch(feedAutoplayProvider);

    return GestureDetector(
      onTap: _onTap,
      child: ready
          ? Stack(
              children: [
                AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
                // Curseur du niveau de lecture, à l'intérieur en bas de la vidéo (glissable)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 14,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.only(top: 10),
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFF1E7DBA),
                          bufferedColor: Color(0x66FFFFFF),
                          backgroundColor: Color(0x33FFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            )
          : _Poster(url: widget.url, showPlay: !autoplay || !_visible),
    );
  }
}
