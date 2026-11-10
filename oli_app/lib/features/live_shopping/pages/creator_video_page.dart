import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/oli_glass.dart';
import '../models/video_sale_model.dart';
import '../providers/video_feed_provider.dart';
import '../widgets/video_player_card.dart';

/// Lecture plein écran d'une vidéo ouverte depuis un profil.
class CreatorVideoPage extends ConsumerStatefulWidget {
  final VideoSale video;

  const CreatorVideoPage({super.key, required this.video});

  @override
  ConsumerState<CreatorVideoPage> createState() => _CreatorVideoPageState();
}

class _CreatorVideoPageState extends ConsumerState<CreatorVideoPage> {
  bool _commentsOpen = false;

  @override
  void initState() {
    super.initState();
    // Les j'aime et commentaires passent par le fil : la vidéo doit y figurer
    Future.microtask(() => ref.read(videoFeedProvider.notifier).ensureVideo(widget.video));
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videoFeedProvider.select((state) => state.videos));
    final video = videos.firstWhereOrNull((v) => v.id == widget.video.id) ?? widget.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayerCard(
            video: video,
            isActive: true,
            onCommentsChanged: (open) => setState(() => _commentsOpen = open),
          ),
          if (!_commentsOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 8,
              child: OliGlassIconButton(
                icon: Icons.arrow_back_ios_new,
                label: 'Retour',
                iconSize: 18,
                onPressed: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }
}
