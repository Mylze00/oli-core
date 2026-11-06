import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

import '../../chat/conversations_page.dart';
import '../../chat/calls_page.dart';
import '../../orders/screens/purchases_page.dart';
import '../../wallet/screens/wallet_screen.dart';


const String _kFontFamily = 'CreatoDisplay';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationProvider);
    final notifications = notificationState.notifications;
    final isLoading = notificationState.isLoading;
    final error = notificationState.error;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: _kFontFamily),
      ),
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(color: Colors.white, fontFamily: _kFontFamily)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Marquer toutes comme lues
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              child: const Text(
                'Tout marquer lu',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),
          // Supprimer toutes les lues
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_read',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Supprimer les lues', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete_read') {
                ref.read(notificationProvider.notifier).deleteAllRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications lues supprimées')),
                );
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null && notifications.isEmpty
              ? _buildErrorState(context, ref, error)
              : notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(notificationProvider.notifier).fetchNotifications();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Colors.white12,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _buildNotificationTile(context, ref, notification);
                        },
                      ),
                    ),
      ),
    );
  }

  /// État d'erreur (API inaccessible, table absente, etc.)
  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    // Détecter si c'est une erreur de connexion vs une erreur serveur
    final isNetworkError = error.toLowerCase().contains('connection') ||
        error.toLowerCase().contains('timeout') ||
        error.toLowerCase().contains('socketexception');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 72,
              color: Colors.redAccent.withOpacity(0.7),
            ),
            const SizedBox(height: 20),
            Text(
              isNetworkError
                  ? 'Impossible de charger les notifications'
                  : 'Une erreur est survenue',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError
                  ? 'Vérifiez votre connexion internet'
                  : 'Le serveur a rencontré un problème',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(notificationProvider.notifier).fetchNotifications();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              size: 46,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Pas de notifications",
            style: TextStyle(
              fontFamily: _kFontFamily,
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Tile d'une notification
  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) {
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(notificationProvider.notifier).deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification "${notification.title}" supprimée'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: notification.isRead
            ? Colors.transparent
            : const Color(0xFF1E1E1E),
        // Pastille style iOS : glyphe blanc sur carré arrondi coloré
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: notification.iconColor,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: notification.iconColor.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(notification.iconData, color: Colors.white, size: 24),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontFamily: _kFontFamily,
            color: Colors.white,
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: const TextStyle(
                fontFamily: _kFontFamily,
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              notification.formattedDateTime,
              style: const TextStyle(
                fontFamily: _kFontFamily,
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          // Marquer comme lue dès l'ouverture
          if (!notification.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }
          _openTarget(context, notification);
        },
      ),
    );
  }

  /// Ouvre l'écran correspondant au type de notification.
  void _openTarget(BuildContext context, NotificationModel notification) {
    Widget? target;
    switch (notification.type) {
      case 'message':
        target = const ConversationsPage();
        break;
      case 'call':
        target = const CallsPage();
        break;
      case 'wallet':
      case 'wallet_deposit':
      case 'payment':
        target = const WalletScreen();
        break;
      case 'order':
        target = const PurchasesPage();
        break;
      default:
        target = null;
    }

    final screen = target;
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      return;
    }

    // Types sans écran dédié (annonce, système) : le détail s'affiche sur place
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(notification.title, style: const TextStyle(color: Colors.white)),
        content: Text(notification.body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

}
