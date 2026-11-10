import '../../../core/theme/oli_glass.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_feed_provider.dart';

/// Motifs acceptés par l'API de signalement, avec leur libellé
const _reportReasons = <String, String>{
  'spam': 'Spam ou publicité trompeuse',
  'arnaque': 'Arnaque',
  'contenu_choquant': 'Contenu choquant ou inapproprié',
  'contrefacon': 'Contrefaçon',
  'autre': 'Autre',
};

/// Volet de signalement d'une vidéo à la modération
class VideoReportSheet extends ConsumerStatefulWidget {
  final String videoId;

  const VideoReportSheet({super.key, required this.videoId});

  @override
  ConsumerState<VideoReportSheet> createState() => _VideoReportSheetState();
}

class _VideoReportSheetState extends ConsumerState<VideoReportSheet> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _isSending = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;

    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(videoFeedProvider.notifier);

    try {
      await notifier.reportVideo(widget.videoId, reason, _detailsController.text.trim());
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Merci, votre signalement a été transmis à la modération')),
      );
      notifier.removeVideo(widget.videoId);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['error']?.toString() : null;
      messenger.showSnackBar(
        SnackBar(
          content: Text(message ?? "Impossible d'envoyer le signalement"),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signaler cette vidéo',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final entry in _reportReasons.entries)
                RadioListTile<String>(
                  value: entry.key,
                  groupValue: _reason,
                  onChanged: _isSending ? null : (value) => setState(() => _reason = value),
                  title: Text(entry.value, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  activeColor: OliPalette.blueOnDark,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                enabled: !_isSending,
                maxLength: 1000,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Précisions (optionnel)',
                  hintStyle: TextStyle(color: Colors.white38),
                  counterStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Color(0xFF0A0A18),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _reason != null && !_isSending ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OliPalette.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_isSending ? 'Envoi...' : 'Envoyer le signalement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
