import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/oli_colors.dart';
import '../../../widgets/auto_refresh_avatar.dart';
import '../chat_controller.dart';
import '../providers/inbox_providers.dart';

/// Choix des discussions vers lesquelles transférer un message (5 au plus).
class ForwardSheet extends ConsumerStatefulWidget {
  /// Ce que l'on voit du message transféré (texte, « Photo », « Message vocal »…).
  final String previewText;

  /// La discussion d'origine n'est pas proposée.
  final String? currentConversationId;

  /// Renvoie un message d'erreur, ou null si le transfert a réussi.
  final Future<String?> Function(List<String> conversationIds) onForward;

  const ForwardSheet({
    super.key,
    required this.previewText,
    required this.onForward,
    this.currentConversationId,
  });

  @override
  ConsumerState<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<ForwardSheet> {
  final Set<String> _selected = {};
  String _query = '';
  bool _isSending = false;

  bool _matches(Map<String, dynamic> conversation) {
    if (_query.isEmpty) return true;
    final text = '${conversation['other_name'] ?? ''} ${conversation['product_name'] ?? ''}'.toLowerCase();
    return text.contains(_query);
  }

  void _toggle(String conversationId) {
    setState(() {
      if (!_selected.remove(conversationId)) {
        if (_selected.length >= kMaxForwardRecipients) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('$kMaxForwardRecipients discussions au maximum')));
          return;
        }
        _selected.add(conversationId);
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final count = _selected.length;
    final error = await widget.onForward(_selected.toList());
    if (!mounted) return;
    if (error != null) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Message transféré à $count discussion${count > 1 ? 's' : ''}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? OliChatDarkColors.bar : Colors.white;
    final muted = isDark ? Colors.white60 : Colors.grey.shade600;
    final fieldColor = isDark ? OliChatDarkColors.receivedBubble : Colors.grey.shade100;
    final conversationsAsync = ref.watch(inboxConversationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Transférer à', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          Text(
                            '${_selected.length}/$kMaxForwardRecipients sélectionnée${_selected.length > 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty || _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Envoyer'),
                    ),
                  ],
                ),
              ),
              // Aperçu du message transféré
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.forward_rounded, size: 18, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.previewText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une discussion',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: fieldColor,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: conversationsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(child: Text('Discussions indisponibles', style: TextStyle(color: muted))),
                  data: (conversations) {
                    final candidates = conversations
                        .where((c) =>
                            c['conversation_id'] != null &&
                            c['conversation_id'].toString() != widget.currentConversationId &&
                            c['is_blocked'] != true &&
                            _matches(c))
                        .toList();
                    if (candidates.isEmpty) {
                      return Center(child: Text('Aucune discussion', style: TextStyle(color: muted)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: candidates.length,
                      itemBuilder: (_, i) {
                        final conversation = candidates[i];
                        final id = conversation['conversation_id'].toString();
                        final productName = conversation['product_name']?.toString();
                        final isSelected = _selected.contains(id);
                        return ListTile(
                          onTap: _isSending ? null : () => _toggle(id),
                          leading: AutoRefreshAvatar(avatarUrl: conversation['other_avatar']?.toString(), size: 44),
                          title: Text(
                            conversation['other_name']?.toString() ?? 'Utilisateur',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: productName == null
                              ? null
                              : Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
                          trailing: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: isSelected ? theme.primaryColor : muted,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
