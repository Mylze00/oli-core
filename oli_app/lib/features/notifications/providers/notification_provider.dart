import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/notification_model.dart';

/// État des notifications
class NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Provider de notifications
class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref _ref;

  NotificationNotifier(this._ref) : super(NotificationState()) {
    fetchNotifications();
  }

  Dio get _dio => _ref.read(dioProvider);

  /// Récupérer toutes les notifications
  Future<void> fetchNotifications() async {
    debugPrint('🔔 [NotificationProvider] Récupération des notifications');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get(ApiConfig.notifications);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List notificationsList = response.data['notifications'] ?? [];
        final int unreadCount = response.data['unreadCount'] ?? 0;

        final notifications = notificationsList
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        debugPrint('   ✅ ${notifications.length} notifications récupérées');

        state = state.copyWith(
          notifications: notifications,
          unreadCount: unreadCount,
          isLoading: false,
        );
      } else {
        throw Exception('Erreur lors de la récupération');
      }
    } catch (e) {
      debugPrint('❌ [NotificationProvider] Erreur: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Récupérer uniquement le compteur de non-lues
  Future<void> fetchUnreadCount() async {
    try {
      final response = await _dio.get('${ApiConfig.notifications}/unread-count');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final count = response.data['count'] ?? 0;
        state = state.copyWith(unreadCount: count);
      }
    } catch (e) {
      debugPrint('❌ Erreur fetchUnreadCount: $e');
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(int id) async {
    try {
      await _dio.put('${ApiConfig.notifications}/$id/read');

      // Mise à jour locale
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == id && !n.isRead) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  /// Marquer toutes comme lues
  Future<void> markAllAsRead() async {
    try {
      await _dio.put('${ApiConfig.notifications}/read-all');

      // Mise à jour locale
      final updatedNotifications = state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      debugPrint('❌ Erreur markAllAsRead: $e');
    }
  }

  /// Supprimer une notification
  Future<void> deleteNotification(int id) async {
    try {
      await _dio.delete('${ApiConfig.notifications}/$id');

      // Retirer de la liste locale
      final notification = state.notifications.firstWhere((n) => n.id == id);
      final updatedNotifications = state.notifications.where((n) => n.id != id).toList();
      
      final newUnreadCount = !notification.isRead && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );
    } catch (e) {
      debugPrint('❌ Erreur deleteNotification: $e');
    }
  }

  /// Supprimer toutes les notifications lues
  Future<void> deleteAllRead() async {
    try {
      await _dio.delete('${ApiConfig.notifications}/read');

      // Garder seulement les non-lues
      final updatedNotifications = state.notifications
          .where((n) => !n.isRead)
          .toList();

      state = state.copyWith(notifications: updatedNotifications);
    } catch (e) {
      debugPrint('❌ Erreur deleteAllRead: $e');
    }
  }

  /// Ajouter une nouvelle notification (pour Socket.io)
  void addNotification(NotificationModel notification) {
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );
  }
}

/// Provider global — utilise le dioProvider centralisé (token automatique)
final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});
