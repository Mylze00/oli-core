import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../../chat/socket_service.dart';
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
    
    // Ecouter les notifications en direct pour mettre à jour la pastille rouge via FCM
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['oli_notification_type'] != 'incoming_call') {
        fetchUnreadCount();
      }
    });

    // Ecouter les notifications en direct via Socket.IO
    _ref.read(socketServiceProvider).onNotification((data) {
      try {
        final notification = NotificationModel.fromJson(data);
        addNotification(notification);
      } catch (e) {
        debugPrint('❌ Erreur parsing notification via socket: $e');
        fetchUnreadCount();
      }
    });
  }

  Dio get _dio => _ref.read(dioProvider);

  /// Indique si une erreur est de type réseau/timeout (retryable)
  bool _isRetryable(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
             error.type == DioExceptionType.receiveTimeout ||
             error.type == DioExceptionType.sendTimeout ||
             error.type == DioExceptionType.connectionError;
    }
    return false;
  }

  /// Récupérer toutes les notifications (avec retry automatique)
  Future<void> fetchNotifications({int maxRetries = 3}) async {
    debugPrint('🔔 [NotificationProvider] Récupération des notifications');

    state = state.copyWith(isLoading: true, error: null);

    int attempt = 0;
    while (attempt < maxRetries) {
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
            error: null,
          );
          return; // Succès → on sort
        } else {
          throw Exception('Erreur lors de la récupération');
        }
      } catch (e) {
        attempt++;
        final retryable = _isRetryable(e);

        if (retryable && attempt < maxRetries) {
          final delay = Duration(seconds: (2 << (attempt - 1))); // 2s, 4s, 8s
          debugPrint('⚠️ [NotificationProvider] Tentative $attempt/$maxRetries échouée. '
              'Retry dans ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          // Erreur non retryable ou max tentatives atteint
          debugPrint('❌ [NotificationProvider] Erreur finale (tentative $attempt/$maxRetries): $e');
          state = state.copyWith(
            isLoading: false,
            error: e.toString(),
          );
          return;
        }
      }
    }
  }


  /// Récupérer uniquement le compteur de non-lues (avec retry silencieux)
  Future<void> fetchUnreadCount({int maxRetries = 2}) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final response = await _dio.get('${ApiConfig.notifications}/unread-count');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final count = response.data['count'] ?? 0;
          state = state.copyWith(unreadCount: count);
          return; // Succès
        }
        return;
      } catch (e) {
        attempt++;
        if (_isRetryable(e) && attempt < maxRetries) {
          final delay = Duration(seconds: (2 << (attempt - 1))); // 2s, 4s
          debugPrint('⚠️ [NotificationProvider] fetchUnreadCount retry $attempt dans ${delay.inSeconds}s');
          await Future.delayed(delay);
        } else {
          debugPrint('❌ Erreur fetchUnreadCount (finale): $e');
          return;
        }
      }
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
