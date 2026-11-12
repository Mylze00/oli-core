import 'package:flutter/material.dart';

import '../../../../core/theme/oli_surface.dart';
import '../../models/feed_model.dart';
import 'feed_media.dart';

/// Post cité dans une publication (« Citer ») : cadre fin avec auteur, texte et média.
class QuotedPostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onTap;

  const QuotedPostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    final handle = (post.authorOliId != null && post.authorOliId!.isNotEmpty) ? '@${post.authorOliId}' : null;
    final hasAvatar = post.authorAvatar != null && post.authorAvatar!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: s.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: s.tile,
                    backgroundImage: hasAvatar ? NetworkImage(post.authorAvatar!) : null,
                    child: hasAvatar
                        ? null
                        : Text(post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 10, color: s.accent, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      post.authorName + (handle != null ? '  $handle' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: s.text, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (post.content != null && post.content!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(post.content!.trim(),
                    maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.text, fontSize: 14, height: 1.3)),
              ),
            if (post.mediaUrl != null) FeedMedia(post: post, still: true, radius: 0),
          ],
        ),
      ),
    );
  }
}
