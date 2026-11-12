import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/oli_surface.dart';
import '../../../core/user/user_provider.dart';
import '../models/feed_model.dart';
import '../providers/feed_provider.dart';
import 'widgets/feed_post_actions.dart';
import 'widgets/feed_media.dart';
import 'widgets/quoted_post_card.dart';

/// Page « Post » façon X : auteur, texte et média, heure · date · vues, barre
/// d'actions (réponses, republier, j'aime, enregistrer, partager), réponses et
/// « Postez votre réponse » en bas. Ouvrir la page compte une vue.
class PostDetailPage extends ConsumerStatefulWidget {
  final FeedPost post;

  /// Ouvrir directement le champ de réponse (bouton « réponses » du Fil).
  final bool focusReply;

  const PostDetailPage({super.key, required this.post, this.focusReply = false});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _sending = false;
  FeedPost? _fresh;

  @override
  void initState() {
    super.initState();
    _replyController.addListener(() => setState(() {}));
    Future.microtask(() async {
      final notifier = ref.read(feedProvider.notifier);
      notifier.recordView(widget.post.id);
      final fresh = await notifier.fetchPost(widget.post.id);
      if (mounted && fresh != null) setState(() => _fresh = fresh);
      await _loadComments();
      if (widget.focusReply && mounted) _replyFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await ref.read(feedProvider.notifier).fetchComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _loadingComments = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final notifier = ref.read(feedProvider.notifier);
    final created = await notifier.addComment(widget.post.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réponse non envoyée, réessayez')));
      return;
    }
    _replyController.clear();
    _replyFocus.unfocus();
    notifier.incrementComments(widget.post.id);
    await _loadComments();
  }

  /// Répondre à une réponse : le champ du bas commence par @auteur.
  void _replyTo(Map<String, dynamic> c) {
    final handle = (c['author_oli_id'] ?? '').toString();
    final mention = handle.isNotEmpty ? '@$handle ' : '@${c['author_name'] ?? ''} ';
    _replyController.text = mention;
    _replyController.selection = TextSelection.collapsed(offset: mention.length);
    _replyFocus.requestFocus();
  }

  /// J'aime sur une réponse : affiché tout de suite, confirmé par le serveur.
  Future<void> _toggleCommentLike(Map<String, dynamic> c) async {
    final id = int.tryParse('${c['id']}');
    if (id == null) return;
    final wasLiked = c['is_liked_by_me'] == true;
    final count = int.tryParse('${c['likes_count'] ?? 0}') ?? 0;
    setState(() {
      c['is_liked_by_me'] = !wasLiked;
      c['likes_count'] = count + (wasLiked ? -1 : 1);
    });
    final result = await ref.read(feedProvider.notifier).toggleCommentLike(id);
    if (!mounted) return;
    setState(() {
      if (result == null) {
        c['is_liked_by_me'] = wasLiked;
        c['likes_count'] = count;
      } else {
        c['is_liked_by_me'] = result['liked'] == true;
        c['likes_count'] = result['count'];
      }
    });
  }

  String _dateLine(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)} · ${two(l.day)}/${two(l.month)}/${l.year.toString().substring(2)}';
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return "à l'instant";
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    // Version la plus à jour : celle du fil (actions immédiates), sinon celle chargée
    ref.watch(feedProvider);
    final post = ref.read(feedProvider.notifier).postById(widget.post.id) ?? _fresh ?? widget.post;
    final myAvatar = ref.watch(userProvider.select((u) => u.value?.avatarUrl));
    final handle = (post.authorOliId != null && post.authorOliId!.isNotEmpty) ? '@${post.authorOliId}' : null;

    return Scaffold(
      backgroundColor: s.background,
      appBar: s.appBar('Post', actions: [
        Builder(
          builder: (buttonContext) => IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: s.text),
            // Menu en verre à côté du bouton
            onPressed: () => showFeedPostMenu(context, ref, post,
                anchorContext: buttonContext, onRemoved: () => Navigator.maybePop(context)),
          ),
        ),
      ]),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: s.accent,
              onRefresh: () async {
                final fresh = await ref.read(feedProvider.notifier).fetchPost(post.id);
                if (mounted && fresh != null) setState(() => _fresh = fresh);
                await _loadComments();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // Auteur
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _Avatar(url: post.authorAvatar, name: post.authorName, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(post.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: s.text, fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                                if (post.authorVerified) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified_rounded, size: 16, color: s.accent),
                                ],
                              ]),
                              if (handle != null) Text(handle, style: TextStyle(color: s.textSecondary, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Texte
                  if (post.content != null && post.content!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SelectableText(post.content!.trim(),
                          style: TextStyle(color: s.text, fontSize: 17, height: 1.35)),
                    ),
                  // Média
                  if (post.mediaUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: FeedMedia(post: post, radius: 16),
                    ),
                  if (post.quotedPost != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: QuotedPostCard(
                        post: post.quotedPost!,
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post.quotedPost!))),
                      ),
                    ),
                  // Heure · date · vues
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: _dateLine(post.createdAt), style: TextStyle(color: s.textSecondary)),
                      TextSpan(text: ' · ', style: TextStyle(color: s.textSecondary)),
                      TextSpan(
                          text: compactCount(post.viewsCount),
                          style: TextStyle(color: s.text, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' vues', style: TextStyle(color: s.textSecondary)),
                    ]), style: const TextStyle(fontSize: 14)),
                  ),
                  Divider(height: 1, color: s.border, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: FeedActionBar(post: post, large: true, onReply: () => _replyFocus.requestFocus()),
                  ),
                  Divider(height: 1, color: s.border),
                  // Réponses
                  if (_loadingComments)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: s.accent)),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text('Aucune réponse pour le moment.\nSoyez le premier à répondre !',
                            textAlign: TextAlign.center, style: TextStyle(color: s.textSecondary)),
                      ),
                    )
                  else
                    for (final c in _comments) _buildComment(s, c),
                ],
              ),
            ),
          ),
          // « Postez votre réponse »
          Container(
            decoration: BoxDecoration(color: s.background, border: Border(top: BorderSide(color: s.border))),
            padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                _Avatar(url: myAvatar, name: 'Moi', radius: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(22)),
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendReply(),
                      style: TextStyle(color: s.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Postez votre réponse',
                        hintStyle: TextStyle(color: s.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _sending
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: s.accent)),
                      )
                    : IconButton(
                        onPressed: _replyController.text.trim().isEmpty ? null : _sendReply,
                        icon: Icon(Icons.send_rounded,
                            color: _replyController.text.trim().isEmpty ? s.textSecondary : OliSurface.oliBlue),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(OliSurface s, Map<String, dynamic> c) {
    final created = DateTime.tryParse('${c['created_at']}');
    final media = c['media_url']?.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: s.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: c['author_avatar']?.toString(), name: '${c['author_name'] ?? '?'}', radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text('${c['author_name'] ?? 'Utilisateur'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: s.text, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  if (created != null)
                    Text('  · ${_ago(created)}', style: TextStyle(color: s.textSecondary, fontSize: 13)),
                ]),
                if ((c['content'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${c['content']}', style: TextStyle(color: s.text, fontSize: 15, height: 1.3)),
                  ),
                // Actions de la réponse : répondre, j'aime
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      _CommentAction(
                        icon: Icons.chat_bubble_outline,
                        color: s.textSecondary,
                        onTap: () => _replyTo(c),
                      ),
                      const SizedBox(width: 24),
                      _CommentAction(
                        icon: c['is_liked_by_me'] == true ? Icons.favorite : Icons.favorite_border,
                        color: c['is_liked_by_me'] == true ? const Color(0xFFF91880) : s.textSecondary,
                        count: int.tryParse('${c['likes_count'] ?? 0}') ?? 0,
                        onTap: () => _toggleCommentLike(c),
                      ),
                    ],
                  ),
                ),
                if (media != null && media.isNotEmpty && c['media_type'] == 'image')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(media, height: 160, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const _Avatar({required this.url, required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final s = OliSurface.of(context);
    final has = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: s.tile,
      backgroundImage: has ? NetworkImage(url!) : null,
      child: has
          ? null
          : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: s.accent, fontWeight: FontWeight.w700, fontSize: radius * 0.8)),
    );
  }
}

/// Petite action sous une réponse (icône + compteur).
class _CommentAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _CommentAction({required this.icon, required this.color, required this.onTap, this.count = 0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(color: color, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
