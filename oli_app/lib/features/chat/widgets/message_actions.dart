import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_page.dart';
import '../providers/inbox_providers.dart';

/// Sélecteur de destinataires pour le Transfert (Forward) de message
/// Limite à 5 destinataires maximum
class ForwardSheet extends ConsumerStatefulWidget {
  final String messageContent;
  final String? mediaUrl;
  final String myId;

  const ForwardSheet({
    super.key,
    required this.messageContent,
    this.mediaUrl,
    required this.myId,
  });

  @override
  ConsumerState<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<ForwardSheet> {
  final Set<String> _selected = {};
  bool _isSending = false;
  static const int _maxRecipients = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archived = ref.watch(archivedConversationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.forward_rounded, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transférer à', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${_selected.length}/$_maxRecipients destinataire${_selected.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11, color: _selected.length >= _maxRecipients ? Colors.red : Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(_isSending ? '…' : 'Envoyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Message preview
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('↪ Transféré', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            widget.messageContent.isEmpty && widget.mediaUrl != null ? '📷 Image' : widget.messageContent,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Contact list (note: in a real app, use actual contacts/conversations)
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 0, // Will be populated from contacts
                  itemBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // Placeholder info
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Chargement des conversations\nen cours…',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _isSending = true);
    // TODO : appeler ChatController.sendMessage pour chaque destinataire avec le contenu
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Message transféré à ${_selected.length} personne${_selected.length > 1 ? 's' : ''}'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

/// Sélecteur de durée pour messages éphémères
class EphemeralTimer extends StatelessWidget {
  final int? currentDays;
  final ValueChanged<int?> onChanged;

  const EphemeralTimer({super.key, required this.currentDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (null, 'Désactivé', Icons.timer_off_outlined),
      (1, '24 heures', Icons.timer_outlined),
      (7, '7 jours', Icons.calendar_view_week_outlined),
      (90, '90 jours', Icons.calendar_month_outlined),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text('Messages éphémères', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Les messages envoyés dans cette discussion s\'effaceront automatiquement après la durée choisie.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        ...options.map((o) {
          final isSelected = currentDays == o.$1;
          return ListTile(
            leading: Icon(o.$3, color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade500),
            title: Text(o.$2, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.black,
            )),
            trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
            onTap: () {
              onChanged(o.$1);
              Navigator.pop(context);
            },
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Menu contextuel d'actions sur un message (long press)
class MessageContextMenu extends StatelessWidget {
  final Map<String, dynamic> message;
  final String myId;
  final bool canEdit; // Seulement dans les 15 premières minutes
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForAll;
  final VoidCallback onForward;
  final VoidCallback onCopy;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.myId,
    required this.canEdit,
    required this.onReply,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForAll,
    required this.onForward,
    required this.onCopy,
  });

  bool get _isMe => message['sender_id'].toString() == myId;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (_isMe && canEdit)
        _Action(icon: Icons.edit_rounded, label: 'Modifier', color: Colors.blue, onTap: onEdit),
      _Action(icon: Icons.reply_rounded, label: 'Répondre', color: Colors.grey.shade700, onTap: onReply),
      _Action(icon: Icons.forward_rounded, label: 'Transférer', color: Colors.grey.shade700, onTap: onForward),
      _Action(icon: Icons.copy_rounded, label: 'Copier', color: Colors.grey.shade700, onTap: onCopy),
      _Action(icon: Icons.delete_outline_rounded, label: 'Supprimer pour moi', color: Colors.orange, onTap: onDeleteForMe),
      if (_isMe)
        _Action(icon: Icons.delete_sweep_rounded, label: 'Supprimer pour tous', color: Colors.red, onTap: onDeleteForAll),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Aperçu du message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message['content'] ?? '📷 Media',
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const Divider(height: 1),

          ...actions.map((a) => ListTile(
            leading: Icon(a.icon, color: a.color, size: 22),
            title: Text(a.label, style: TextStyle(color: a.color, fontSize: 14)),
            dense: true,
            onTap: () {
              Navigator.pop(context);
              a.onTap();
            },
          )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});
}
