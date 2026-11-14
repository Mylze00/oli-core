import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Affiche une image reçue en plein écran, avec zoom et enregistrement.
class ChatImageViewer extends StatefulWidget {
  final String imageUrl;

  const ChatImageViewer({super.key, required this.imageUrl});

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  bool _isSaving = false;

  /// Cloudinary propose alors le fichier au téléchargement au lieu de l'afficher.
  String get _downloadUrl => widget.imageUrl.contains('/image/upload/')
      ? widget.imageUrl.replaceFirst('/image/upload/', '/image/upload/fl_attachment/')
      : widget.imageUrl;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (kIsWeb) {
        await launchUrl(Uri.parse(_downloadUrl), webOnlyWindowName: '_blank');
      } else {
        final response = await Dio().get<List<int>>(
          widget.imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        await Share.shareXFiles([
          XFile.fromData(
            Uint8List.fromList(response.data!),
            mimeType: 'image/jpeg',
            name: 'image_oli.jpg',
          ),
        ]);
      }
    } catch (e) {
      debugPrint("Erreur d'enregistrement de l'image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'enregistrer cette image")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Enregistrer l'image",
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: OliImage.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
