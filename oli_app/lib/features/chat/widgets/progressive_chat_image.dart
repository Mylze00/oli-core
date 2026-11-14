import 'package:oli_app/core/widgets/oli_image.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

const _chatImageHeight = 200.0;
const _maxUploadBlur = 14.0;
const _thumbnailBlur = 6.0;
const _maxSentImages = 20;

/// Images envoyées depuis cet appareil, pour ne pas les retélécharger juste après l'envoi.
class SentImageCache {
  SentImageCache._();

  static final Map<String, Uint8List> _images = {};

  static Uint8List? get(String url) => _images[url];

  static void put(String url, Uint8List bytes) {
    if (_images.length >= _maxSentImages) _images.remove(_images.keys.first);
    _images[url] = bytes;
  }
}

/// Image en cours d'envoi : d'abord floue, elle s'affine avec la progression réelle.
class UploadingChatImage extends StatelessWidget {
  final Uint8List bytes;
  final double progress;

  const UploadingChatImage({super.key, required this.bytes, required this.progress});

  @override
  Widget build(BuildContext context) {
    final blur = (1 - progress.clamp(0.0, 1.0)) * _maxUploadBlur;
    final image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);

    return SizedBox(
      height: _chatImageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blur > 0)
            ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: image)
          else
            image,
          Center(
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
              child: CircularProgressIndicator(
                // À 100 %, le serveur finit encore d'enregistrer l'image
                value: progress < 1 ? progress : null,
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Image reçue : une miniature floue s'affiche, puis l'image complète la remplace en fondu.
class ProgressiveChatImage extends StatelessWidget {
  final String url;

  const ProgressiveChatImage({super.key, required this.url});

  String? get _thumbnailUrl => url.contains('/image/upload/')
      ? url.replaceFirst('/image/upload/', '/image/upload/w_48,q_30,f_auto/')
      : null;

  @override
  Widget build(BuildContext context) {
    final sentBytes = SentImageCache.get(url);
    final thumbnailUrl = _thumbnailUrl;

    return SizedBox(
      height: _chatImageHeight,
      width: double.infinity,
      child: sentBytes != null
          ? Image.memory(sentBytes, fit: BoxFit.cover, gaplessPlayback: true)
          : Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl != null)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: _thumbnailBlur, sigmaY: _thumbnailBlur),
                    child: OliImage.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                    ),
                  )
                else
                  const ColoredBox(color: Colors.black12),
                OliImage.network(
                  url,
                  fit: BoxFit.cover,
                  frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: child,
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ],
            ),
    );
  }
}
