import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';
import 'product_bottom_sheet.dart';

/// Carte vidéo plein écran style TikTok
class VideoPlayerCard extends ConsumerStatefulWidget {
  final VideoSale video;
  final bool isActive;

  const VideoPlayerCard({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  ConsumerState<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends ConsumerState<VideoPlayerCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showPlayIcon = false;
  bool _showHeart = false;
  Timer? _viewTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          if (widget.isActive) {
            _controller.play();
            _startViewTimer();
          }
        }
      });
  }

  void _startViewTimer() {
    _viewTimer?.cancel();
    _viewTimer = Timer(const Duration(seconds: 3), () {
      ref.read(videoFeedProvider.notifier).registerView(widget.video.id);
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
      _startViewTimer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
      _viewTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _showPlayIcon = true);
    } else {
      _controller.play();
      setState(() => _showPlayIcon = false);
    }
  }

  void _onDoubleTap() {
    ref.read(videoFeedProvider.notifier).toggleLike(widget.video.id);
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Vidéo ou placeholder ──
        GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: _onDoubleTap,
          child: _isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white24,
                      strokeWidth: 2,
                    ),
                  ),
                ),
        ),

        // ── Icône play/pause ──
        if (_showPlayIcon)
          const Center(
            child: Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 80),
          ),

        // ── Animation cœur (double-tap) ──
        if (_showHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.2),
              duration: const Duration(milliseconds: 400),
              builder: (_, scale, __) => Transform.scale(
                scale: scale,
                child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100),
              ),
            ),
          ),

        // ── Gradient bas ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 250,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
        ),

        // ── Overlay droite : interactions ──
        Positioned(
          right: 12,
          bottom: 160,
          child: _buildRightOverlay(),
        ),

        // ── Overlay bas : infos + bouton achat ──
        Positioned(
          bottom: 20,
          left: 16,
          right: 80,
          child: _buildBottomOverlay(),
        ),

        // ── Progress bar ──
        if (_isInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRightOverlay() {
    final video = widget.video;
    return Column(
      children: [
        // Avatar vendeur
        GestureDetector(
          onTap: () {
            // TODO: Naviguer vers le profil vendeur
          },
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[800],
                backgroundImage: video.sellerAvatar != null
                    ? NetworkImage(video.sellerAvatar!)
                    : null,
                child: video.sellerAvatar == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 20)
                    : null,
              ),
              if (video.sellerCertified)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.verified, color: Colors.blue[400], size: 16),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Like
        _interactionButton(
          icon: video.isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatNumber(video.likesCount),
          color: video.isLiked ? Colors.redAccent : Colors.white,
          onTap: () => ref.read(videoFeedProvider.notifier).toggleLike(video.id),
        ),

        const SizedBox(height: 20),

        // Vues
        _interactionButton(
          icon: Icons.visibility_outlined,
          label: _formatNumber(video.viewsCount),
          color: Colors.white70,
          onTap: null,
        ),

        const SizedBox(height: 20),

        // Partage
        _interactionButton(
          icon: Icons.share_outlined,
          label: 'Partager',
          color: Colors.white,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Partage bientôt disponible'),
                backgroundColor: Color(0xFF1A1A2E),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _interactionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay() {
    final video = widget.video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nom du vendeur
        Row(
          children: [
            Text(
              '@${video.sellerName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (video.sellerCertified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified, color: Colors.blue[400], size: 14),
            ],
          ],
        ),

        const SizedBox(height: 6),

        // Titre de la vidéo
        if (video.title != null)
          Text(
            video.title!,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 12),

        // Bouton d'achat lié au produit
        if (video.productId != null)
          GestureDetector(
            onTap: () => _showProductSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6D00).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      video.productName ?? 'Voir le produit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (video.productPrice != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '\$${video.productPrice!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showProductSheet() {
    _controller.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductBottomSheet(video: widget.video),
    ).then((_) {
      if (widget.isActive) _controller.play();
    });
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
