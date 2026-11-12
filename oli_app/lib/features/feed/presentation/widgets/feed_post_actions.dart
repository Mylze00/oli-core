import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/oli_surface.dart';
import '../../../marketplace/presentation/pages/seller_profile_page.dart';
import '../../models/feed_model.dart';
import '../../providers/feed_provider.dart';

/// Nombre court façon X : 950 · 1,2 k · 96,7 k · 1,3 M.
String compactCount(int n) {
  String one(double v) => v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',').replaceAll(',0', '');
  if (n >= 1000000) return '${one(n / 1000000)} M';
  if (n >= 1000) return '${one(n / 1000)} k';
  return '$n';
}

/// Partage du post (texte, auteur et lien vers Oli).
Future<void> shareFeedPost(FeedPost post) async {
  final text = [
    if (post.content != null && post.content!.trim().isNotEmpty) post.content!.trim(),
    '— ${post.authorName} sur Oli',
    'https://oli-core.web.app',
  ].join('\n');
  await Share.share(text);
}

/// Barre d'actions : réponses, republier, j'aime, enregistrer, partager.
class FeedActionBar extends ConsumerWidget {
  final FeedPost post;
  final VoidCallback onReply;

  /// Page « Post » : icônes un peu plus grandes.
  final bool large;

  const FeedActionBar({super.key, required this.post, required this.onReply, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = OliSurface.of(context);
    final notifier = ref.read(feedProvider.notifier);
    final size = large ? 22.0 : 19.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(icon: Icons.chat_bubble_outline_rounded, count: post.commentsCount, color: s.textSecondary, size: size, onTap: onReply),
        _ActionButton(
          icon: Icons.repeat_rounded,
          count: post.repostsCount,
          color: post.isRepostedByMe ? s.success : s.textSecondary,
          size: size + 2,
          onTap: () {
            HapticFeedback.selectionClick();
            notifier.toggleRepost(post);
          },
        ),
        _ActionButton(
          icon: post.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          count: post.likesCount,
          color: post.isLikedByMe ? const Color(0xFFF91880) : s.textSecondary,
          size: size,
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.toggleLike(post.id);
          },
        ),
        _ActionButton(
          icon: post.isBookmarkedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          count: post.bookmarksCount,
          color: post.isBookmarkedByMe ? s.accent : s.textSecondary,
          size: size,
          onTap: () {
            HapticFeedback.selectionClick();
            notifier.toggleBookmark(post);
          },
        ),
        _ActionButton(icon: Icons.ios_share_rounded, color: s.textSecondary, size: size, onTap: () => shareFeedPost(post)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.size, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(icon, key: ValueKey('$icon$color'), size: size, color: color),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(compactCount(count!), style: TextStyle(color: color, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menu « ⋯ » d'un post. [onRemoved] : le post a quitté le fil (masqué, signalé, supprimé).
Future<void> showFeedPostMenu(BuildContext context, WidgetRef ref, FeedPost post, {VoidCallback? onRemoved}) async {
  final s = OliSurface.of(context);
  final notifier = ref.read(feedProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final handle = (post.authorOliId != null && post.authorOliId!.isNotEmpty) ? '@${post.authorOliId}' : post.authorName;

  Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
        leading: Icon(icon, color: color ?? s.text),
        title: Text(label, style: TextStyle(color: color ?? s.text, fontSize: 15, fontWeight: FontWeight.w500)),
        onTap: onTap,
      );

  await showModalBottomSheet(
    context: context,
    backgroundColor: s.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) {
      void close() => Navigator.pop(sheet);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: s.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            if (post.isMine) ...[
              item(Icons.bar_chart_rounded, 'Voir les interactions avec le post', () {
                close();
                showFeedInteractions(context, ref, post);
              }),
              item(Icons.delete_outline_rounded, 'Supprimer le post', () async {
                close();
                final ok = await _confirm(context, 'Supprimer ce post ?', 'Il sera retiré du Fil pour tout le monde.', 'Supprimer');
                if (ok != true) return;
                final done = await notifier.deletePost(post.id);
                messenger.showSnackBar(SnackBar(content: Text(done ? 'Post supprimé' : 'Suppression impossible')));
                if (done) onRemoved?.call();
              }, color: s.danger),
            ] else ...[
              item(Icons.visibility_off_outlined, 'Masquer ce post', () async {
                close();
                await notifier.hidePost(post.id);
                messenger.showSnackBar(const SnackBar(content: Text('Post masqué : vous ne le verrez plus')));
                onRemoved?.call();
              }),
              item(Icons.flag_outlined, 'Signaler le post', () async {
                close();
                final details = await _askReport(context);
                if (details == null) return;
                await notifier.reportPost(post.id, reason: 'report', details: details.isEmpty ? null : details);
                messenger.showSnackBar(const SnackBar(content: Text('Merci, le post a été signalé')));
                onRemoved?.call();
              }),
              item(Icons.report_gmailerrorred_outlined, 'Marquer comme spam', () async {
                close();
                await notifier.reportPost(post.id, reason: 'spam');
                messenger.showSnackBar(const SnackBar(content: Text('Marqué comme spam')));
                onRemoved?.call();
              }),
            ],
            if (post.content != null && post.content!.trim().isNotEmpty)
              item(Icons.copy_rounded, 'Copier le texte', () {
                close();
                Clipboard.setData(ClipboardData(text: post.content!.trim()));
                messenger.showSnackBar(const SnackBar(content: Text('Texte copié')));
              }),
            if (post.authorId != null)
              item(Icons.person_outline_rounded, 'Voir le profil $handle', () {
                close();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SellerProfilePage(sellerId: post.authorId.toString())),
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<bool?> _confirm(BuildContext context, String title, String message, String action) {
  final s = OliSurface.of(context);
  return showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: s.card,
      title: Text(title, style: TextStyle(color: s.text)),
      content: Text(message, style: TextStyle(color: s.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(action, style: TextStyle(color: s.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Motif du signalement (facultatif). null = annulé.
Future<String?> _askReport(BuildContext context) {
  final s = OliSurface.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: s.card,
      title: Text('Signaler le post', style: TextStyle(color: s.text)),
      content: TextField(
        controller: controller,
        maxLines: 3,
        style: TextStyle(color: s.text),
        decoration: InputDecoration(
          hintText: 'Pourquoi ce post pose problème ? (facultatif)',
          hintStyle: TextStyle(color: s.textSecondary),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(d, controller.text.trim()),
          child: Text('Signaler', style: TextStyle(color: s.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Interactions avec son post : vues, réponses, republications, j'aime, enregistrements,
/// et les dernières personnes qui ont aimé ou republié.
Future<void> showFeedInteractions(BuildContext context, WidgetRef ref, FeedPost post) async {
  final s = OliSurface.of(context);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: s.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(feedProvider.notifier).fetchInteractions(post.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(strokeWidth: 2, color: s.accent));
          }
          final d = snap.data;
          if (d == null) {
            return Center(child: Text('Interactions indisponibles', style: TextStyle(color: s.textSecondary)));
          }
          Widget stat(String label, dynamic value) => Expanded(
                child: Column(
                  children: [
                    Text(compactCount(int.tryParse('$value') ?? 0),
                        style: TextStyle(color: s.text, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(label, style: TextStyle(color: s.textSecondary, fontSize: 11)),
                  ],
                ),
              );
          Widget people(String title, List list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Text(title, style: TextStyle(color: s.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Personne pour le moment', style: TextStyle(color: s.textSecondary, fontSize: 13)),
                    ),
                  for (final p in list)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: s.tile,
                        backgroundImage: (p['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(p['avatar_url']) : null,
                        child: (p['avatar_url'] ?? '').toString().isEmpty
                            ? Icon(Icons.person_rounded, size: 18, color: s.textSecondary)
                            : null,
                      ),
                      title: Text('${p['name'] ?? 'Utilisateur'}', style: TextStyle(color: s.text, fontSize: 14)),
                    ),
                ],
              );
          return ListView(
            controller: controller,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: s.border, borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('Interactions avec le post', style: TextStyle(color: s.text, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: s.tile, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  stat('Vues', d['views']),
                  stat('Réponses', d['comments']),
                  stat('Republi.', d['reposts']),
                  stat("J'aime", d['likes']),
                  stat('Enreg.', d['bookmarks']),
                ]),
              ),
              people("Ont aimé", (d['liked_by'] as List?) ?? const []),
              people('Ont republié', (d['reposted_by'] as List?) ?? const []),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    ),
  );
}
