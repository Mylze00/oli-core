import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
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
      error: error,
    );
  }
}

/// Provider de notifications
class NotificationNotifier extends StateNotifier<NotificationState> {
  final Dio _dio;
  final SecureStorageService _storage;

  NotificationNotifier(this._dio, this._storage) : super(NotificationState()) {
    fetchNotifications();
  }

  /// Récupérer toutes les notifications
  Future<void> fetchNotifications() async {
    print('🔔 [NotificationProvider] Récupération des notifications');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final token = await _storage.getToken();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      final response = await _dio.get(
        '/notifications',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List notificationsList = response.data['notifications'] ?? [];
        final int unreadCount = response.data['unreadCount'] ?? 0;

        final notifications = notificationsList
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        print('   ✅ ${notifications.length} notifications récupérées');
        print('   - ${unreadCount} non lues');

        state = state.copyWith(
          notifications: notifications,
          unreadCount: unreadCount,
          isLoading: false,
        );
      } else {
        throw Exception('Erreur lors de la récupération');
      }
    } catch (e) {
      print('❌ [NotificationProvider] Erreur: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Récupérer uniquement le compteur de non-lues
  Future<void> fetchUnreadCount() async {
    try {
      final token = await _storage.getToken();
      if (token == null) return;

      final response = await _dio.get(
        '/notifications/unread-count',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final count = response.data['count'] ?? 0;
        state = state.copyWith(unreadCount: count);
      }
    } catch (e) {
      print('❌ Erreur fetchUnreadCount: $e');
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(int id) async {
    print('📖 [NotificationProvider] Marquer notification $id comme lue');

    try {
      final token = await _storage.getToken();
      if (token == null) return;

      await _dio.put(
        '/notifications/$id/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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

      print('   ✅ Notification marquée comme lue');
    } catch (e) {
      print('❌ Erreur markAsRead: $e');
    }
  }

  /// Marquer toutes comme lues
  Future<void> markAllAsRead() async {
    print('📖 [NotificationProvider] Marquer toutes comme lues');

    try {
      final token = await _storage.getToken();
      if (token == null) return;

      await _dio.put(
        '/notifications/read-all',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Mise à jour locale
      final updatedNotifications = state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );

      print('   ✅ Toutes les notifications marquées comme lues');
    } catch (e) {
      print('❌ Erreur markAllAsRead: $e');
    }
  }

  /// Supprimer une notification
  Future<void> deleteNotification(int id) async {
    print('🗑️ [NotificationProvider] Suppression notification $id');

    try {
      final token = await _storage.getToken();
      if (token == null) return;

      await _dio.delete(
        '/notifications/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Retirer de la liste locale
      final notification = state.notifications.firstWhere((n) => n.id == id);
      final updatedNotifications = state.notifications.where((n) => n.id != id).toList();
      
      // Décrémenter unreadCount si la notification n'était pas lue
      final newUnreadCount = !notification.isRead && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );

      print('   ✅ Notification supprimée');
    } catch (e) {
      print('❌ Erreur deleteNotification: $e');
    }
  }

  /// Supprimer toutes les notifications lues
  Future<void> deleteAllRead() async {
    print('🗑️ [NotificationProvider] Suppression de toutes les lues');

    try {
      final token = await _storage.getToken();
      if (token == null) return;

      await _dio.delete(
        '/notifications/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Garder seulement les non-lues
      final updatedNotifications = state.notifications
          .where((n) => !n.isRead)
          .toList();

      state = state.copyWith(notifications: updatedNotifications);

      print('   ✅ Notifications lues supprimées');
    } catch (e) {
      print('❌ Erreur deleteAllRead: $e');
    }
  }

  /// Ajouter une nouvelle notification (pour Socket.io)
  void addNotification(NotificationModel notification) {
    print('➕ [NotificationProvider] Nouvelle notification reçue');
    
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );
  }
}

/// Provider global
final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final storage = SecureStorageService();
  return NotificationNotifier(dio, storage);
});
