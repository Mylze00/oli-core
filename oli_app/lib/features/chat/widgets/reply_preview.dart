import 'package:flutter/material.dart';

/// Barre d'aperçu du message auquel on répond
/// Affiché au-dessus de ChatInputArea quand l'utilisateur swipe un message
class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyToMessage;
  final String currentUserId;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.replyToMessage,
    required this.currentUserId,
    required this.onCancel,
  });

  String get _senderLabel {
    final senderId = replyToMessage['sender_id']?.toString() ?? '';
    if (senderId == currentUserId) return 'Vous';
    return replyToMessage['sender_name'] ?? 'Utilisateur';
  }

  String get _contentPreview {
    final type = replyToMessage['type'] ?? 'text';
    final meta = replyToMessage['metadata'];

    if (type == 'location') return '📍 Position partagée';
    if (type == 'audio') return '🎤 Message vocal';

    String? mediaType;
    if (meta != null) {
      try {
        final metaMap = meta is String
            ? <String, dynamic>{} // simplified
            : (meta as Map<String, dynamic>);
        mediaType = metaMap['mediaType']?.toString();
      } catch (_) {}
    }

    if (mediaType == 'image') return '📷 Photo';
    if (mediaType == 'audio') return '🎤 Message vocal';

    final content = replyToMessage['content']?.toString() ?? '';
    if (content.startsWith('💸')) return content;
    if (content.isEmpty) return '📎 Média';
    return content.length > 80 ? '${content.substring(0, 80)}…' : content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.primaryColor, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _senderLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _contentPreview,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
