import 'package:flutter/material.dart';
import '../../models/feed_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feed_provider.dart';

class FeedPostWidget extends ConsumerWidget {
  final FeedPost post;

  const FeedPostWidget({Key? key, required this.post}) : super(key: key);

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: post.authorAvatar != null ? NetworkImage(post.authorAvatar!) : null,
            child: post.authorAvatar == null ? Text(post.authorName[0].toUpperCase()) : null,
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Name + Time)
                Row(
                  children: [
                    Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('· ${_formatTime(post.createdAt)}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                // Text Content
                if (post.content != null && post.content!.isNotEmpty)
                  Text(post.content!, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                
                // Media
                if (post.mediaUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(post.mediaUrl!, fit: BoxFit.cover, width: double.infinity, height: 200),
                  ),
                
                const SizedBox(height: 12),
                
                // Interaction Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Comment
                    _InteractionButton(
                      icon: Icons.chat_bubble_outline,
                      count: post.commentsCount,
                      onTap: () {
                        // TODO: Open comments modal
                      },
                    ),
                    // Like
                    _InteractionButton(
                      icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      color: post.isLikedByMe ? Colors.red : Colors.grey[600]!,
                      count: post.likesCount,
                      onTap: () {
                        ref.read(feedProvider.notifier).toggleLike(post.id);
                      },
                    ),
                    // Share
                    _InteractionButton(
                      icon: Icons.ios_share,
                      onTap: () {
                        // TODO: Share logic
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    this.color = Colors.black54,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(count.toString(), style: TextStyle(color: color, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}
