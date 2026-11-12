import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/oli_surface.dart';
import '../../models/feed_model.dart';
import '../post_detail_page.dart';
import 'feed_post_actions.dart';
import 'feed_media.dart';
import 'quoted_post_card.dart';

/// Carte d'un post dans le Fil, façon X : avatar, nom, @identifiant, ancienneté,
/// menu « ⋯ », texte, média et barre d'actions. Toucher la carte ouvre la page « Post ».
class FeedPostWidget extends ConsumerWidget {
  final FeedPost post;

  /// Aperçu figé (menu contextuel) : pas d'action, pas de lecture vidéo.
  final bool still;

  const FeedPostWidget({Key? key, required this.post, this.still = false}) : super(key: key);

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    final l = time.toLocal();
    return '${l.day}/${l.month}/${l.year.toString().substring(2)}';
  }

  void _open(BuildContext context, {bool reply = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post, focusReply: reply)));
  }

  /// Menu en verre à côté de la carte, avec l'aperçu du post détaché (comme la liste des discussions).
  void _openMenu(BuildContext cardContext, WidgetRef ref) {
    showFeedPostMenu(cardContext, ref, post,
        anchorContext: cardContext, preview: FeedPostWidget(post: post, still: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = OliSurface.of(context);
    final handle = (post.authorOliId != null && post.authorOliId!.isNotEmpty) ? '@${post.authorOliId}' : null;
    final hasAvatar = post.authorAvatar != null && post.authorAvatar!.isNotEmpty;

    return Material(
      color: s.background,
      child: InkWell(
        onTap: still ? null : () => _open(context),
        onLongPress: still ? null : () => _openMenu(context, ref),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: s.border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: s.tile,
                backgroundImage: hasAvatar ? NetworkImage(post.authorAvatar!) : null,
                child: hasAvatar
                    ? null
                    : Text(post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                        style: TextStyle(color: s.accent, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom · @identifiant · ancienneté · ⋯
                    Row(
                      children: [
                        Flexible(
                          child: Text(post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: s.text, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (post.authorVerified) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.verified_rounded, size: 15, color: s.accent),
                        ],
                        Flexible(
                          child: Text(
                            '${handle != null ? '  $handle' : ''} · ${_ago(post.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: s.textSecondary, fontSize: 14),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 32,
                          height: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: Icon(Icons.more_horiz_rounded, color: s.textSecondary),
                            onPressed: still ? null : () => _openMenu(context, ref),
                          ),
                        ),
                      ],
                    ),
                    if (post.content != null && post.content!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 8),
                        child: Text(post.content!, style: TextStyle(fontSize: 15, color: s.text, height: 1.35)),
                      ),
                    if (post.mediaUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, right: 8),
                        child: FeedMedia(post: post, still: still),
                      ),
                    if (post.quotedPost != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, right: 8),
                        child: QuotedPostCard(
                          post: post.quotedPost!,
                          onTap: still
                              ? null
                              : () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => PostDetailPage(post: post.quotedPost!))),
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (still)
                      const SizedBox(height: 8)
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: FeedActionBar(post: post, onReply: () => _open(context, reply: true)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
