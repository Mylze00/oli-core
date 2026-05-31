import 'package:flutter/material.dart';
import '../../models/feed_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feed_provider.dart';
import 'feed_comments_bottom_sheet.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black12;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            backgroundImage: post.authorAvatar != null ? NetworkImage(post.authorAvatar!) : null,
            child: post.authorAvatar == null ? Text(post.authorName[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
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
                    Text(post.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const SizedBox(width: 8),
                    Text('· ${_formatTime(post.createdAt)}', style: TextStyle(color: subtextColor)),
                  ],
                ),
                const SizedBox(height: 4),
                // Text Content
                if (post.content != null && post.content!.isNotEmpty)
                  Text(post.content!, style: TextStyle(fontSize: 15, color: textColor)),
                const SizedBox(height: 12),
                
                // Media
                if (post.mediaUrl != null)
                  Builder(
                    builder: (context) {
                      String displayUrl = post.mediaUrl!;
                      if (post.mediaType == 'video' && displayUrl.contains('cloudinary')) {
                         displayUrl = displayUrl.replaceAll(RegExp(r'\.[^.]+$'), '.jpg'); // Cloudinary video thumbnail
                      }
                      
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              displayUrl, 
                              fit: BoxFit.cover, 
                              width: double.infinity, 
                              height: 200,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              ),
                            ),
                          ),
                          if (post.mediaType == 'video')
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                        ],
                      );
                    }
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
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => FeedCommentsBottomSheet(postId: post.id),
                        );
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
    this.color = Colors.grey,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color == Colors.grey ? (isDark ? Colors.grey[400]! : Colors.black54) : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(count.toString(), style: TextStyle(color: effectiveColor, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}
