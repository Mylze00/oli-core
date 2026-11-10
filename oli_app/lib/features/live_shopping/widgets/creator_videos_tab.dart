import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../core/user/user_provider.dart';
import '../models/creator_profile_model.dart';
import '../models/video_sale_model.dart';
import '../pages/creator_video_page.dart';
import '../pages/video_upload_page.dart';
import '../providers/video_feed_provider.dart';

const _cardColor = Color(0xFF1E1E1E);
const _pointRules = [
  ('Vidéo publiée', 20),
  ('Vente depuis une vidéo', 50),
  ('Commentaire reçu', 8),
  ("J'aime reçu", 5),
  ('Produit en ligne', 5),
  ('Vue', 1),
];

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} k';
  return '$value';
}

/// Onglet du profil : score du créateur, statistiques et vidéos publiées.
class CreatorVideosTab extends ConsumerWidget {
  final String userId;

  const CreatorVideosTab({super.key, required this.userId});

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VideoUploadPage()),
    );
    if (published == true) ref.invalidate(creatorProfileProvider(userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(userProvider).value?.id.toString() == userId;

    return ref.watch(creatorProfileProvider(userId)).when(
      loading: () => const Center(child: CircularProgressIndicator(color: OliPalette.blueOnDark)),
      error: (_, __) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(creatorProfileProvider(userId)),
          icon: const Icon(Icons.refresh, color: OliPalette.blueOnDark),
          label: const Text('Réessayer', style: TextStyle(color: OliPalette.blueOnDark)),
        ),
      ),
      data: (profile) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                _buildScoreCard(profile, isOwner),
                const SizedBox(height: 12),
                _buildStatsGrid(profile),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  _buildPointRules(),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _publish(context, ref),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Publier une vidéo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OliPalette.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Vidéos publiées',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _buildVideoGrid(profile.videos),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildScoreCard(CreatorProfile profile, bool isOwner) {
    final nextLevel = profile.nextLevel;
    final String encouragement;
    if (nextLevel == null) {
      encouragement = 'Niveau maximal atteint. Bravo !';
    } else if (isOwner) {
      encouragement = 'Encore ${_formatCount(profile.pointsToNext)} points pour passer $nextLevel. '
          'Chaque nouvelle vidéo vous rapproche du niveau suivant.';
    } else {
      encouragement = 'Encore ${_formatCount(profile.pointsToNext)} points pour passer $nextLevel';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [OliPalette.navyLight, OliPalette.blue]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Niveau ${profile.level}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(TextSpan(
            style: const TextStyle(color: Colors.white),
            children: [
              TextSpan(
                text: _formatCount(profile.score),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' points', style: TextStyle(fontSize: 16)),
            ],
          )),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: profile.levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(encouragement, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(CreatorProfile profile) {
    final stats = [
      ('Vidéos', profile.videosCount, Icons.play_circle_outline),
      ('Produits', profile.productsCount, Icons.inventory_2_outlined),
      ('Vues', profile.viewsCount, Icons.visibility_outlined),
      ("J'aime", profile.likesCount, Icons.favorite_border),
      ('Commentaires', profile.commentsCount, Icons.chat_bubble_outline),
      ('Ventes vidéo', profile.videoSalesCount, Icons.shopping_bag_outlined),
    ];
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (label, value, icon) in stats)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: OliPalette.blueOnDark, size: 20),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatCount(value),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPointRules() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment gagner des points',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final (label, points) in _pointRules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                  Text(
                    '+$points',
                    style: const TextStyle(color: OliPalette.blueOnDark, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(List<VideoSale> videos) {
    if (videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Aucune vidéo publiée pour le moment.', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.62,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) => _VideoTile(video: videos[index]),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final VideoSale video;

  const _VideoTile({required this.video});

  Widget _buildCounter(IconData icon, int value) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(_formatCount(value), style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;
    return Semantics(
      button: true,
      label: 'Voir la vidéo ${video.title ?? ''}',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreatorVideoPage(video: video)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: _cardColor,
                child: thumbnail == null
                    ? const Icon(Icons.play_circle_outline, color: Colors.grey, size: 32)
                    : Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.play_circle_outline, color: Colors.grey, size: 32),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _buildCounter(Icons.favorite, video.likesCount),
                      _buildCounter(Icons.chat_bubble, video.commentsCount),
                      _buildCounter(Icons.visibility, video.viewsCount),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
