import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/config/api_config.dart';
import '../core/providers/dio_provider.dart';

/// Service de push notifications via Firebase Cloud Messaging
class PushNotificationService {
  final Ref _ref;
  String? _currentToken;

  PushNotificationService(this._ref);

  /// Initialiser les notifications push
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // 1. Demander la permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('⚠️ [FCM] Notifications refusées par l\'utilisateur');
      return;
    }

    debugPrint('✅ [FCM] Permission accordée: ${settings.authorizationStatus}');

    // 2. Obtenir le token FCM
    try {
      _currentToken = await messaging.getToken();
      if (_currentToken != null) {
        debugPrint('📱 [FCM] Token: ${_currentToken!.substring(0, 20)}...');
        await _registerToken(_currentToken!);
      }
    } catch (e) {
      debugPrint('❌ [FCM] Erreur obtention token: $e');
    }

    // 3. Écouter les rafraîchissements de token
    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 [FCM] Token rafraîchi');
      _currentToken = newToken;
      _registerToken(newToken);
    });

    // 4. Messages en foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Messages quand l'app est ouverte depuis une notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 6. Vérifier si l'app a été ouverte depuis une notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📬 [FCM] App ouverte via notification');
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Enregistrer le token FCM auprès du backend
  Future<void> _registerToken(String token) async {
    try {
      final dio = _ref.read(dioProvider);
      final platform = Platform.isAndroid ? 'android' : 'ios';

      await dio.post(
        ApiConfig.deviceTokens,
        data: {
          'token': token,
          'platform': platform,
        },
      );
      debugPrint('✅ [FCM] Token enregistré sur le backend ($platform)');
    } catch (e) {
      debugPrint('❌ [FCM] Erreur enregistrement token: $e');
    }
  }

  /// Supprimer le token au logout
  Future<void> unregister() async {
    if (_currentToken == null) return;
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete(
        ApiConfig.deviceTokens,
        data: {'token': _currentToken},
      );
      debugPrint('🗑️ [FCM] Token supprimé du backend');
    } catch (e) {
      debugPrint('❌ [FCM] Erreur suppression token: $e');
    }
  }

  /// Gérer un message reçu en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 [FCM] Message foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Afficher une notification locale via SnackBar ou overlay
    // (utilise le navigatorKey si disponible)
    debugPrint('   📌 ${notification.title}: ${notification.body}');
  }

  /// Gérer le tap sur une notification (app en background/terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📬 [FCM] Notification tappée: ${message.data}');

    // Naviguer vers la commande si l'ID est dans les data
    final orderId = message.data['order_id'] ?? message.data['orderId'];
    if (orderId != null) {
      debugPrint('   🔗 Navigation vers commande #$orderId');
      // Navigation sera gérée par le GoRouter dans une version future
    }
  }

  String? get currentToken => _currentToken;
}

/// Provider Riverpod
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
