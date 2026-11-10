import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/oli_glass.dart';
import '../providers/video_publish_provider.dart';

/// Laisse la place au bouton retour et aux actions des barres d'application.
const _sideInset = 56.0;

/// Affiche partout dans l'application l'avancement d'une publication en arrière-plan.
class VideoPublishBanner extends ConsumerWidget {
  final Widget child;

  const VideoPublishBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoPublishProvider);
    final isVisible = state.inBackground && state.status != VideoPublishStatus.idle;

    return Stack(
      children: [
        child,
        if (isVisible)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: _sideInset,
            right: _sideInset,
            child: _BannerContent(state: state),
          ),
      ],
    );
  }
}

class _BannerContent extends ConsumerWidget {
  final VideoPublishState state;

  const _BannerContent({required this.state});

  String get _label {
    switch (state.status) {
      case VideoPublishStatus.uploading:
        return 'Envoi ${(state.progress * 100).floor()} %';
      case VideoPublishStatus.finalizing:
        return 'Finalisation...';
      case VideoPublishStatus.failed:
        return "Échec de l'envoi";
      case VideoPublishStatus.done:
        return 'Vidéo publiée';
      case VideoPublishStatus.idle:
        return '';
    }
  }

  Widget _buildLeading() {
    if (state.status == VideoPublishStatus.done) {
      return const Icon(Icons.check_circle, color: Colors.white, size: 26);
    }
    final thumbnail = state.thumbnail;
    if (thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(thumbnail, width: 28, height: 28, fit: BoxFit.cover, cacheWidth: 84),
      );
    }
    return const Icon(Icons.videocam, color: Colors.white, size: 24);
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 44),
          icon: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoPublishProvider.notifier);
    final isFailed = state.status == VideoPublishStatus.failed;
    final isUploading = state.status == VideoPublishStatus.uploading;

    return Material(
      color: isFailed ? const Color(0xFFB3261E) : OliPalette.blue,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  _buildLeading(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isFailed) _buildAction(Icons.refresh, 'Réessayer', notifier.retry),
                  if (state.status != VideoPublishStatus.finalizing)
                    _buildAction(
                      Icons.close,
                      state.status == VideoPublishStatus.done ? 'Fermer' : "Annuler l'envoi",
                      state.status == VideoPublishStatus.done ? notifier.dismiss : notifier.cancel,
                    ),
                ],
              ),
            ),
            if (isUploading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
