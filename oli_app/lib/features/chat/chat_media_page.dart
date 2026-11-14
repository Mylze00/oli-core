import 'package:oli_app/core/widgets/oli_image.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import 'widgets/chat_image_viewer.dart';

final _linkPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

Map<String, dynamic>? _metadataOf(Map<String, dynamic> message) {
  final raw = message['metadata'];
  try {
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    if (raw is Map) return Map<String, dynamic>.from(raw);
  } catch (_) {}
  return null;
}

/// Miniature légère pour la grille quand l'image est sur Cloudinary.
String _gridThumbnail(String url) => url.contains('/image/upload/')
    ? url.replaceFirst('/image/upload/', '/image/upload/w_300,h_300,c_fill,q_auto,f_auto/')
    : url;

String _absoluteUrl(String url) => url.startsWith('http') ? url : '${ApiConfig.baseUrl}/$url';

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir ce lien")));
    }
  }
}

/// Photos, liens et documents échangés dans la discussion (parmi les messages chargés).
class ChatMediaPage extends StatelessWidget {
  final String otherName;
  final List<Map<String, dynamic>> messages;

  const ChatMediaPage({super.key, required this.otherName, required this.messages});

  @override
  Widget build(BuildContext context) {
    final images = <String>[];
    final documents = <({String url, String name})>[];
    final links = <({String url, String date})>[];

    // Du plus récent au plus ancien
    for (final message in messages.reversed) {
      if (message['deleted_at'] != null) continue;
      final metadata = _metadataOf(message);
      final mediaUrl = metadata?['mediaUrl']?.toString();
      final mediaType = metadata?['mediaType']?.toString();
      if (mediaUrl != null && mediaType == 'image') {
        images.add(_absoluteUrl(mediaUrl));
      } else if (mediaUrl != null && mediaType != 'audio' && !mediaUrl.endsWith('.m4a')) {
        documents.add((url: _absoluteUrl(mediaUrl), name: Uri.decodeComponent(mediaUrl.split('/').last)));
      }
      final content = message['content']?.toString() ?? '';
      final date = DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal();
      for (final match in _linkPattern.allMatches(content)) {
        links.add((url: match.group(0)!, date: date == null ? '' : '${date.day}/${date.month}/${date.year}'));
      }
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(otherName),
          bottom: TabBar(tabs: [
            Tab(text: 'Médias (${images.length})'),
            Tab(text: 'Liens (${links.length})'),
            Tab(text: 'Docs (${documents.length})'),
          ]),
        ),
        body: TabBarView(
          children: [
            images.isEmpty
                ? const _Empty(icon: Icons.photo_library_outlined, text: 'Aucune photo échangée')
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatImageViewer(imageUrl: images[i])),
                      ),
                      child: OliImage.network(
                        _gridThumbnail(images[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
            links.isEmpty
                ? const _Empty(icon: Icons.link, text: 'Aucun lien échangé')
                : ListView.separated(
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(links[i].url, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: links[i].date.isEmpty ? null : Text(links[i].date),
                      onTap: () => _open(context, links[i].url),
                    ),
                  ),
            documents.isEmpty
                ? const _Empty(icon: Icons.description_outlined, text: 'Aucun document échangé')
                : ListView.separated(
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(documents[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(context, documents[i].url),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).hintColor),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}
