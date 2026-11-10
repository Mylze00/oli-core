import '../../core/theme/oli_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../live_shopping/providers/video_feed_provider.dart';
import '../live_shopping/widgets/video_player_card.dart';
import '../live_shopping/pages/video_upload_page.dart';
import '../marketplace/presentation/pages/seller_profile_page.dart';
import '../../core/user/user_provider.dart';

/// Page principale Live Shopping — Feed vidéo style TikTok
class LiveShoppingPage extends ConsumerStatefulWidget {
  const LiveShoppingPage({super.key});

  @override
  ConsumerState<LiveShoppingPage> createState() => _LiveShoppingPageState();
}

class _LiveShoppingPageState extends ConsumerState<LiveShoppingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _commentsOpen = false;

  @override
  void initState() {
    super.initState();
    // Charger les vidéos au démarrage
    Future.microtask(() {
      ref.read(videoFeedProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Ouvre la publication puis revient en tête du fil pour afficher la nouvelle vidéo.
  Future<void> _openUploadPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoUploadPage()),
    );
    if (result != true || !mounted) return;

    await ref.read(videoFeedProvider.notifier).loadFeed();
    if (!mounted) return;
    setState(() => _currentPage = 0);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(videoFeedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _commentsOpen ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Shopping',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Score du créateur connecté
          IconButton(
            tooltip: 'Mon score',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 22),
            ),
            onPressed: () {
              final userId = ref.read(userProvider).value?.id.toString();
              if (userId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerProfilePage(sellerId: userId, openVideosTab: true),
                ),
              );
            },
          ),
          // Bouton upload
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            onPressed: _openUploadPage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(feedState),
    );
  }

  Widget _buildBody(VideoFeedState feedState) {
    // Loading
    if (feedState.isLoading && feedState.videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
      );
    }

    // Erreur
    if (feedState.error != null && feedState.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            Text(
              feedState.error!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.read(videoFeedProvider.notifier).loadFeed(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // Vide
    if (feedState.videos.isEmpty) {
      return _buildEmptyState();
    }

    // Une vidéo signalée peut disparaître en fin de liste
    final activeIndex = _currentPage.clamp(0, feedState.videos.length - 1);

    // Feed TikTok
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      // Le défilement du fil est suspendu pendant la lecture des commentaires
      physics: _commentsOpen ? const NeverScrollableScrollPhysics() : null,
      itemCount: feedState.videos.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);

        // Charger plus quand on approche de la fin
        if (index >= feedState.videos.length - 3) {
          ref.read(videoFeedProvider.notifier).loadMore();
        }
      },
      itemBuilder: (context, index) {
        final video = feedState.videos[index];
        return VideoPlayerCard(
          // La clé garantit un lecteur propre à chaque vidéo quand le fil change
          key: ValueKey(video.id),
          video: video,
          isActive: index == activeIndex,
          onCommentsChanged: (open) => setState(() => _commentsOpen = open),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône animée
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OliPalette.blueOnDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.live_tv,
              size: 64,
              color: OliPalette.blueOnDark,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune vidéo pour le moment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Soyez le premier à publier une vidéo de vente et atteignez des milliers d\'acheteurs !',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openUploadPage,
            icon: const Icon(Icons.videocam, size: 20),
            label: const Text(
              'Publier une vidéo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: OliPalette.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
