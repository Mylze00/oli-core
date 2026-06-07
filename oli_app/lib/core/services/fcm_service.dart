import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';

// NavigatorKey global pour naviguer depuis le background handler
final GlobalKey<NavigatorState> fcmNavigatorKey = GlobalKey<NavigatorState>();

/// Handler pour les messages en arrière-plan (DOIT être top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final isIncomingCall = data['oli_notification_type'] == 'incoming_call';

  debugPrint('[FCM BG] Message reçu: type=${data['oli_notification_type']}');

  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await localNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  if (isIncomingCall) {
    // ── Notification d'appel entrant ─────────────────────────────────────
    final callerName = data['caller_name'] ?? 'Utilisateur OLI';
    final callType = data['call_type'] ?? 'audio';

    await localNotifications.show(
      999, // ID fixe pour l'appel (remplace toujours le même)
      '📞 Appel ${callType == 'video' ? 'vidéo' : 'audio'} entrant',
      '$callerName vous appelle',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'oli_calls',
          'Appels OLI',
          channelDescription: 'Notifications d\'appels entrants',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // Ouvre sur écran verrouillé
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          visibility: NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          timeoutAfter: 30000, // 30 secondes
          actions: [
            const AndroidNotificationAction('accept', '✅ Décrocher', showsUserInterface: true),
            const AndroidNotificationAction('reject', '❌ Refuser'),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'incoming_call|${data['caller_id']}|${data['caller_name']}|${data['call_type']}|${data['conversation_id']}',
    );
  } else if (data.isNotEmpty) {
    // ── Notification standard ───────────────────────────────────────────
    final title = message.notification?.title ?? data['title'] ?? 'OLI';
    final body = message.notification?.body ?? data['body'] ?? 'Nouvelle notification';

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'oli_notifications',
          'Notifications OLI',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}

/// Service FCM — Gestion des push notifications et appels entrants
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final SecureStorageService _storage = SecureStorageService();

  bool _initialized = false;

  // Callback pour déclencher l'affichage de CallScreen depuis n'importe où
  Function(Map<String, String> callData)? onIncomingCall;

  /// Canal d'appels (pleine priorité)
  static const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
    'oli_calls',
    'Appels OLI',
    description: 'Notifications pour les appels entrants OLI',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: false,
  );

  /// Canal de notifications standard
  static const AndroidNotificationChannel _notifChannel = AndroidNotificationChannel(
    'oli_notifications',
    'Notifications OLI',
    description: 'Notifications générales de l\'application OLI',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialiser FCM (appeler dans main.dart après Firebase.initializeApp)
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Demander la permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
        provisional: false,
      );

      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission refusée');
        return;
      }

      // 2. Initialiser les notifications locales
      await _initLocalNotifications();

      // 3. Récupérer et enregistrer le token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _registerToken(token);
      }

      // 4. Renouvellement de token
      _messaging.onTokenRefresh.listen(_registerToken);

      // 5. Configurer les handlers de messages
      _setupMessageHandlers();

      // 6. Vérifier si l'app a été ouverte depuis une notification d'appel
      _checkInitialMessage();

      _initialized = true;
      debugPrint('[FCM] Service initialisé');
    } catch (e) {
      debugPrint('[FCM] Erreur init: $e');
    }
  }

  /// Initialiser les notifications locales avec les canaux Android
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload ?? '');
      },
      onDidReceiveBackgroundNotificationResponse: _handleBgNotificationTap,
    );

    // Créer les canaux Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_callChannel);
    await androidPlugin?.createNotificationChannel(_notifChannel);
  }

  /// Configurer les handlers FCM (foreground + background tap)
  void _setupMessageHandlers() {
    // Foreground : message reçu quand l'app est ouverte
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.data}');
      final data = message.data;

      if (data['oli_notification_type'] == 'incoming_call') {
        // Déclencher directement le CallScreen si callback défini
        if (onIncomingCall != null) {
          onIncomingCall!({
            'callerId': data['caller_id'] ?? '',
            'callerName': data['caller_name'] ?? 'Utilisateur OLI',
            'callerAvatar': data['caller_avatar'] ?? '',
            'callType': data['call_type'] ?? 'audio',
            'conversationId': data['conversation_id'] ?? '',
          });
        }
        _showCallNotification(data);
      } else {
        _showLocalNotification(message);
      }
    });

    // Background tap : user tape la notification quand app est en BG
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification ouverte depuis BG: ${message.data}');
      _handleFcmData(message.data);
    });
  }

  /// Vérifier si l'app a été lancée depuis une notification (app terminée)
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App lancée depuis notification: ${initialMessage.data}');
      // Petit délai pour que l'app soit initialisée
      await Future.delayed(const Duration(milliseconds: 500));
      _handleFcmData(initialMessage.data);
    }
  }

  /// Traiter les données FCM pour naviguer vers le bon écran
  void _handleFcmData(Map<String, dynamic> data) {
    if (data['oli_notification_type'] == 'incoming_call') {
      if (onIncomingCall != null) {
        onIncomingCall!({
          'callerId': data['caller_id']?.toString() ?? '',
          'callerName': data['caller_name']?.toString() ?? 'Utilisateur OLI',
          'callerAvatar': data['caller_avatar']?.toString() ?? '',
          'callType': data['call_type']?.toString() ?? 'audio',
          'conversationId': data['conversation_id']?.toString() ?? '',
        });
      }
    }
  }

  /// Afficher la notification d'appel (foreground ou BG)
  Future<void> _showCallNotification(Map<String, dynamic> data) async {
    final callerName = data['caller_name'] ?? 'Utilisateur OLI';
    final callType = data['call_type'] ?? 'audio';

    await _localNotifications.show(
      999,
      '📞 Appel ${callType == 'video' ? 'vidéo' : 'audio'} entrant',
      '$callerName vous appelle',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'oli_calls',
          'Appels OLI',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          timeoutAfter: 30000,
          actions: [
            const AndroidNotificationAction('accept', '✅ Décrocher', showsUserInterface: true),
            const AndroidNotificationAction('reject', '❌ Refuser'),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'incoming_call|${data['caller_id']}|${data['caller_name']}|${data['call_type']}|${data['conversation_id']}',
    );
  }

  /// Afficher une notification standard (foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null && message.data.isEmpty) return;

    final title = notification?.title ?? message.data['title'] ?? 'OLI';
    final body = notification?.body ?? message.data['body'] ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'oli_notifications',
          'Notifications OLI',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Handler tap notification locale
  void _handleNotificationTap(String payload) {
    if (payload.startsWith('incoming_call|')) {
      final parts = payload.split('|');
      if (onIncomingCall != null && parts.length >= 4) {
        onIncomingCall!({
          'callerId': parts[1],
          'callerName': parts[2],
          'callType': parts[3],
          'conversationId': parts.length > 4 ? parts[4] : '',
        });
      }
    }
  }

  /// Enregistrer le token FCM auprès du backend
  Future<void> _registerToken(String fcmToken) async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) return;

      await _dio.post(
        '/device-tokens',
        data: {
          'token': fcmToken,
          'platform': _getPlatform(),
        },
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      debugPrint('[FCM] Token enregistré');
    } catch (e) {
      debugPrint('[FCM] Erreur enregistrement token: $e');
    }
  }

  /// Supprimer le token FCM (lors de la déconnexion)
  Future<void> removeToken() async {
    try {
      final authToken = await _storage.getToken();
      final fcmToken = await _messaging.getToken();

      if (authToken != null && fcmToken != null) {
        await _dio.delete(
          '/device-tokens',
          data: {'token': fcmToken},
          options: Options(headers: {'Authorization': 'Bearer $authToken'}),
        );
      }

      _initialized = false;
      debugPrint('[FCM] Token supprimé');
    } catch (e) {
      debugPrint('[FCM] Erreur suppression token: $e');
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}

// Handler tap depuis background (top-level requis)
@pragma('vm:entry-point')
void _handleBgNotificationTap(NotificationResponse response) {
  debugPrint('[FCM BG TAP] payload: ${response.payload}');
}
