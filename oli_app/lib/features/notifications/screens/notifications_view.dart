import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationProvider);
    final notifications = notificationState.notifications;
    final isLoading = notificationState.isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.white)),
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
    );
  }

  /// État vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.blueAccent.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            "Pas de notifications",
            style: TextStyle(
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
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getColorByType(notification.type).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              notification.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
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
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              notification.relativeTime,
              style: const TextStyle(
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
          // Marquer comme lue si non-lue
          if (!notification.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }

          // TODO: Navigation selon le type de notification
          // Par exemple, si type='message', naviguer vers la conversation
          // Si type='order', naviguer vers la commande, etc.
        },
      ),
    );
  }

  /// Obtenir la couleur selon le type
  Color _getColorByType(String type) {
    switch (type) {
      case 'message':
        return Colors.blue;
      case 'order':
        return Colors.orange;
      case 'offer':
        return Colors.purple;
      case 'announcement':
        return Colors.red;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
