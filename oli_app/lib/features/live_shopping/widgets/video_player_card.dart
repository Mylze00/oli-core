import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';
import 'product_bottom_sheet.dart';
import 'floating_likes.dart';
import 'video_comments_panel.dart';
import 'video_report_sheet.dart';
import '../../marketplace/presentation/pages/seller_profile_page.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../core/user/user_provider.dart';
import '../../../providers/exchange_rate_provider.dart';
import '../../../utils/cloudinary_helper.dart';

const _commentsAnimation = Duration(milliseconds: 280);

/// Part de la hauteur gardée par la vidéo quand les commentaires sont ouverts.
const _reducedVideoRatio = 0.34;
const _maxVideoLoadAttempts = 8;
const _videoLoadRetryDelay = Duration(seconds: 8);

/// Carte vidéo plein écran style TikTok
class VideoPlayerCard extends ConsumerStatefulWidget {
  final VideoSale video;
  final bool isActive;
  final ValueChanged<bool>? onCommentsChanged;

  const VideoPlayerCard({
    super.key,
    required this.video,
    required this.isActive,
    this.onCommentsChanged,
  });

  @override
  ConsumerState<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends ConsumerState<VideoPlayerCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _userPaused = false;
  bool _isRouteCurrent = true;
  bool _showHeart = false;
  bool _viewRegistered = false;
  bool _commentsOpen = false;
  bool _commentsMounted = false;
  bool _likesBurstPlayed = false;
  bool _showLikesBurst = false;
  Timer? _viewTimer;
  Timer? _reloadTimer;
  int _loadAttempts = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    _loadAttempts++;
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _syncPlayback();
        }
      }).catchError((Object error) {
        debugPrint('Vidéo non disponible (essai $_loadAttempts): $error');
        if (mounted) _scheduleVideoReload();
      });
  }

  /// Une vidéo récente peut être encore en cours de conversion par Cloudinary.
  void _scheduleVideoReload() {
    if (_loadAttempts >= _maxVideoLoadAttempts) {
      setState(() => _loadFailed = true);
      return;
    }
    _reloadTimer = Timer(_videoLoadRetryDelay, () {
      _controller.dispose();
      if (mounted) _initVideo();
    });
  }

  /// Aligne la lecture sur l'état de la carte : visible, non recouverte, non mise en pause.
  void _syncPlayback() {
    if (!_isInitialized) return;
    final shouldPlay = widget.isActive && _isRouteCurrent && !_userPaused;
    if (shouldPlay == _controller.value.isPlaying) return;

    if (shouldPlay) {
      _controller.play();
      _startViewTimer();
      _playLikesBurstOnce();
    } else {
      _controller.pause();
      _viewTimer?.cancel();
    }
  }

  /// Lance l'effet des j'aime à la première lecture de la vidéo.
  void _playLikesBurstOnce() {
    if (_likesBurstPlayed || widget.video.likesCount == 0) return;
    _likesBurstPlayed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showLikesBurst = true);
    });
  }

  void _setCommentsOpen(bool open) {
    setState(() {
      _commentsOpen = open;
      if (open) _commentsMounted = true;
    });
    widget.onCommentsChanged?.call(open);
  }

  void _startViewTimer() {
    if (_viewRegistered) return;
    _viewTimer?.cancel();
    _viewTimer = Timer(const Duration(seconds: 3), () {
      _viewRegistered = true;
      ref.read(videoFeedProvider.notifier).registerView(widget.video.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Une page ou un volet ouvert par-dessus met la vidéo en pause
    _isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) _userPaused = false;
    _syncPlayback();
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _reloadTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _userPaused = !_userPaused);
    _syncPlayback();
  }

  void _openSellerProfile() {
    final sellerId = widget.video.sellerId;
    if (sellerId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: sellerId)),
    );
  }

  Future<void> _shareVideo() async {
    final video = widget.video;
    final String text;
    if (video.productId != null) {
      final price = video.productPrice != null
          ? '\n${ref.read(exchangeRateProvider.notifier).formatProductPrice(video.productPrice!)}'
          : '';
      text = "Regarde ce produit en vidéo sur Oli : ${video.productName ?? 'Produit'}$price\n"
          'https://oli-app.web.app/product/${video.productId}';
    } else {
      text = 'Regarde les vidéos de ${video.sellerName} sur Oli\nhttps://oli-app.web.app';
    }

    try {
      await Share.share(text);
    } catch (e) {
      debugPrint('Erreur partage vidéo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de partager cette vidéo')),
        );
      }
    }
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VideoReportSheet(videoId: widget.video.id),
    );
  }

  /// Formate un prix produit selon la devise choisie dans l'application.
  String _formatPrice(double price) {
    ref.watch(exchangeRateProvider);
    return ref.read(exchangeRateProvider.notifier).formatProductPrice(price);
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
    return PopScope(
      canPop: !_commentsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setCommentsOpen(false);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final reducedHeight = height * _reducedVideoRatio;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),

              // ── Vidéo, réduite quand les commentaires sont ouverts ──
              AnimatedPositioned(
                duration: _commentsAnimation,
                curve: Curves.easeOut,
                top: 0,
                left: 0,
                right: 0,
                height: _commentsOpen ? reducedHeight : height,
                child: _buildVideoArea(),
              ),

              if (_userPaused && !_commentsOpen)
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

              if (!_commentsOpen) ...[
                // ── Gradient bas ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 250,
                  child: IgnorePointer(
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
                ),

                // ── Effet des j'aime au lancement ──
                if (_showLikesBurst)
                  Positioned(
                    right: 0,
                    bottom: 260,
                    width: 80,
                    height: height * 0.5,
                    child: FloatingLikes(
                      likesCount: widget.video.likesCount,
                      onFinished: () => setState(() => _showLikesBurst = false),
                    ),
                  ),

                // ── Overlay droite : interactions ──
                Positioned(
                  right: 12,
                  bottom: 160,
                  child: _buildRightOverlay(),
                ),

                // ── Overlay bas : infos + produit ──
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

              // ── Commentaires ──
              AnimatedPositioned(
                duration: _commentsAnimation,
                curve: Curves.easeOut,
                top: _commentsOpen ? reducedHeight : height,
                left: 0,
                right: 0,
                height: height - reducedHeight,
                child: _commentsMounted
                    ? VideoCommentsPanel(
                        video: widget.video,
                        onClose: () => _setCommentsOpen(false),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoArea() {
    return GestureDetector(
      onTap: _commentsOpen ? () => _setCommentsOpen(false) : _togglePlay,
      onDoubleTap: _onDoubleTap,
      child: Container(
        color: Colors.black,
        padding: EdgeInsets.only(top: _commentsOpen ? MediaQuery.of(context).viewPadding.top : 0),
        child: _isInitialized
            ? ClipRect(
                child: FittedBox(
                  fit: _commentsOpen ? BoxFit.contain : BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : Center(
                child: _loadFailed
                    ? const Text('Vidéo indisponible', style: TextStyle(color: Colors.white54))
                    : const CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
              ),
      ),
    );
  }

  Widget _buildRightOverlay() {
    final video = widget.video;
    final currentUserId = ref.watch(userProvider).value?.id.toString();
    return Column(
      children: [
        // Avatar vendeur
        GestureDetector(
          onTap: _openSellerProfile,
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

        // Commentaires
        _interactionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatNumber(video.commentsCount),
          color: Colors.white,
          onTap: () => _setCommentsOpen(true),
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
          onTap: _shareVideo,
        ),

        // Signalement (impossible sur sa propre vidéo)
        if (currentUserId != video.sellerId) ...[
          const SizedBox(height: 20),
          _interactionButton(
            icon: Icons.flag_outlined,
            label: 'Signaler',
            color: Colors.white70,
            onTap: _showReportSheet,
          ),
        ],
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

        // La vignette du produit ouvre la fiche d'achat
        if (video.productId != null) _buildProductMiniCard(),
      ],
    );
  }

  /// Vignette : image du produit, nom et prix (ouvre la fiche produit au tap).
  Widget _buildProductMiniCard() {
    final video = widget.video;
    final image = (video.productImages != null && video.productImages!.isNotEmpty)
        ? video.productImages!.first
        : null;
    return GestureDetector(
      onTap: _showProductSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: image == null
                    ? const ColoredBox(
                        color: Color(0xFF222222),
                        child: Icon(Icons.image, color: Colors.white38),
                      )
                    : Image.network(
                        CloudinaryHelper.card(image),
                        fit: BoxFit.cover,
                        cacheWidth: 180,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF222222),
                          child: Icon(Icons.broken_image, color: Colors.white38),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Produit en vedette',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    video.productName ?? 'Produit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (video.productPrice != null)
                    Text(
                      _formatPrice(video.productPrice!),
                      style: const TextStyle(color: OliPalette.blueOnDark, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductBottomSheet(video: widget.video),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
