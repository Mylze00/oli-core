import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../config/api_config.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'location_message_bubble.dart';
import 'audio_message_bubble.dart';

class ChatMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String? otherAvatarUrl;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.otherAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // Extraction Metadata
    String? mediaUrl;
    String? mediaType;
    Map<String, dynamic>? metaMap;
    
    if (message['metadata'] != null) {
      try {
        metaMap = message['metadata'] is String 
            ? jsonDecode(message['metadata']) 
            : message['metadata'];
        mediaUrl = metaMap?['mediaUrl'];
        mediaType = metaMap?['mediaType'];
      } catch (e) { /* ignore */ }
    }

    // Check if it's a location message
    final bool isLocation = message['type'] == 'location' || 
                            (metaMap != null && metaMap.containsKey('lat') && metaMap.containsKey('lng'));

    // Determine timestamp
    String timeString = '';
    if (message['created_at'] != null) {
      try {
        final date = DateTime.parse(message['created_at']).toLocal();
        timeString = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      } catch (e) { /* ignore */ }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for Other User
          if (!isMe) ...[
            AutoRefreshAvatar(
              avatarUrl: otherAvatarUrl,
              size: 28,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: size.width * 0.75),
              padding: isLocation ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isLocation ? Colors.transparent : (isMe ? theme.primaryColor : Colors.white),
                borderRadius: BorderRadius.circular(18),
                boxShadow: isLocation ? [] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isLocation 
                ? LocationMessageBubble(metadata: metaMap!, isMe: isMe)
                : (mediaType == 'audio' || (mediaUrl != null && mediaUrl.endsWith('.m4a')))
                    ? AudioMessageBubble(audioUrl: mediaUrl!, isMe: isMe)
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Image / Media
                    if (mediaUrl != null && mediaType != 'audio')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            mediaUrl.startsWith('http') ? mediaUrl : '${ApiConfig.baseUrl}/$mediaUrl',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                            loadingBuilder: (ctx, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.black12,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                            },
                          ),
                        ),
                      ),
                  
                  // Text Content
                  if (message['content'] != null && message['content'].toString().isNotEmpty && message['content'] != '📷 Image')
                    Text(
                      message['content'],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.3
                      ),
                    ),
                  
                  // Metadata Row (Time + Ticks)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (timeString.isNotEmpty)
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white.withOpacity(0.7) : Colors.black38,
                            ),
                          ),
                        
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          if (message['id'].toString().startsWith('temp_'))
                            Icon(Icons.access_time, size: 12, color: Colors.white.withOpacity(0.7))
                          else if (message['is_read'] == true)
                            const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent) // Blue ticks
                          else
                            Icon(Icons.check, size: 14, color: Colors.white.withOpacity(0.7)), // Grey tick
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
