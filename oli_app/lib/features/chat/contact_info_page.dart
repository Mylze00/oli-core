import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/auto_refresh_avatar.dart';
import 'chat_controller.dart';
import 'providers/inbox_providers.dart';

const _danger = Color(0xFFE5484D);

/// Fiche du contact ouverte depuis le menu ⋮ de la discussion.
class ContactInfoPage extends ConsumerWidget {
  final String otherId;
  final String otherName;
  final String? avatarUrl;
  final int mediaCount;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final VoidCallback onSearch;
  final VoidCallback onOpenMedia;
  final VoidCallback onTheme;
  final VoidCallback onEphemeral;

  const ContactInfoPage({
    super.key,
    required this.otherId,
    required this.otherName,
    required this.avatarUrl,
    required this.mediaCount,
    required this.onAudioCall,
    required this.onVideoCall,
    required this.onSearch,
    required this.onOpenMedia,
    required this.onTheme,
    required this.onEphemeral,
  });

  void _showResult(BuildContext context, String? error, String success) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? success)));
  }

  Future<void> _chooseMute(BuildContext context, WidgetRef ref, String conversationId, bool isMuted) async {
    const options = [
      ('8h', '8 heures', 'Silence activé pour 8 heures'),
      ('1w', '1 semaine', 'Silence activé pour 1 semaine'),
      ('always', 'Toujours', 'Silence activé'),
    ];
    final choice = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(option.$2),
                onTap: () => Navigator.pop(ctx, (option.$1, option.$3)),
              ),
            if (isMuted)
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Réactiver les notifications'),
                onTap: () => Navigator.pop(ctx, ('off', 'Notifications réactivées')),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final error = await ref.read(inboxConversationsProvider.notifier).setMute(conversationId, choice.$1);
    if (context.mounted) _showResult(context, error, choice.$2);
  }

  Future<void> _toggleBlock(BuildContext context, WidgetRef ref, bool isBlocked) async {
    if (!isBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Bloquer $otherName ?'),
          content: const Text('Vous ne recevrez plus ses messages ni ses appels.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: _danger),
              child: const Text('Bloquer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final error = await ref.read(inboxConversationsProvider.notifier).setBlocked(otherId, !isBlocked);
    if (context.mounted) _showResult(context, error, isBlocked ? '$otherName débloqué' : '$otherName bloqué');
  }

  /// Ferme la fiche puis lance l'action sur la discussion.
  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatControllerProvider(otherId));
    final conversationId = chatState.conversationId?.toString();
    final conversations = ref.watch(inboxConversationsProvider).value ?? const <Map<String, dynamic>>[];
    final conversation = conversations.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['conversation_id']?.toString() == conversationId,
          orElse: () => null,
        );
    final phone = conversation?['other_phone']?.toString();
    final isBlocked = conversation?['is_blocked'] == true;
    final isMuted = conversation?['is_muted'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Infos du contact')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(child: AutoRefreshAvatar(avatarUrl: avatarUrl, size: 112)),
          const SizedBox(height: 12),
          Text(otherName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (phone != null && phone.isNotEmpty)
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: phone));
                _showResult(context, null, 'Numéro copié');
              },
              child: Text(phone, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: theme.hintColor)),
            ),
          const SizedBox(height: 4),
          Text(
            chatState.isOtherUserOnline ? 'En ligne' : 'Hors ligne',
            textAlign: TextAlign.center,
            style: TextStyle(color: chatState.isOtherUserOnline ? Colors.green : theme.hintColor, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _QuickAction(icon: Icons.phone, label: 'Audio', onTap: () => _closeThen(context, onAudioCall)),
                _QuickAction(icon: Icons.videocam, label: 'Vidéo', onTap: () => _closeThen(context, onVideoCall)),
                _QuickAction(icon: Icons.search, label: 'Rechercher', onTap: () => _closeThen(context, onSearch)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Médias, liens et docs'),
            trailing: Text('$mediaCount', style: TextStyle(color: theme.hintColor)),
            onTap: onOpenMedia,
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Messages éphémères'),
            subtitle: Text(ephemeralLabel(chatState.ephemeralSeconds)),
            onTap: onEphemeral,
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Thème de la discussion'),
            onTap: onTheme,
          ),
          if (conversationId != null)
            ListTile(
              leading: Icon(isMuted ? Icons.notifications_off : Icons.notifications_none),
              title: const Text('Mode silencieux'),
              subtitle: Text(isMuted ? 'Activé' : 'Désactivé'),
              onTap: () => _chooseMute(context, ref, conversationId, isMuted),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block, color: _danger),
            title: Text(isBlocked ? 'Débloquer $otherName' : 'Bloquer $otherName', style: const TextStyle(color: _danger)),
            onTap: () => _toggleBlock(context, ref, isBlocked),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: theme.primaryColor),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
