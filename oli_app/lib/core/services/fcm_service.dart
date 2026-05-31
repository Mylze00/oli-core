import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Handler pour les messages en arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 [FCM] Message reçu en arrière-plan: ${message.messageId}');

  // Affichage manuel si c'est un message de données (Appel ou Message critique)
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] ?? 'Oli';
    final body = message.data['body'] ?? 'Vous avez une nouvelle notification';
    final isCall = message.data['type'] == 'call';

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await localNotifications.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));

    final androidChannel = AndroidNotificationDetails(
      isCall ? 'oli_calls_bg' : 'oli_notifications_bg',
      isCall ? 'Appels Oli' : 'Notifications Arrière-plan',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: isCall, // Réveille l'écran pour les appels
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    await localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidChannel,
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
      ),
      payload: message.data.toString(),
    );
  }
}

/// Service FCM pour gérer les push notifications
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final SecureStorageService _storage = SecureStorageService();

  bool _initialized = false;

  /// Canal de notification Android (Haute priorité)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'oli_notifications',
    'Notifications Oli',
    description: 'Notifications de l\'application Oli',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialiser FCM (appeler après login)
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Demander la permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 [FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ [FCM] Permission refusée par l\'utilisateur');
        return;
      }

      // 2. Initialiser les notifications locales (pour afficher en foreground)
      await _initLocalNotifications();

      // 3. Récupérer et enregistrer le token
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 [FCM] Token: ${token.substring(0, 20)}...');
        await _registerToken(token);
      }

      // 4. Écouter le renouvellement du token
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [FCM] Token renouvelé');
        _registerToken(newToken);
      });

      // 5. Configurer les handlers de messages
      _setupMessageHandlers();

      _initialized = true;
      debugPrint('✅ [FCM] Service initialisé');
    } catch (e) {
      debugPrint('❌ [FCM] Erreur d\'initialisation: $e');
    }
  }

  /// Initialiser les notifications locales
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🔔 [FCM] Notification locale tappée: ${response.payload}');
        // TODO: Navigation vers la page appropriée selon le payload
      },
    );

    // Créer le canal Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Configurer les handlers de messages FCM
  void _setupMessageHandlers() {
    // Message reçu quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM] Message foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Quand l'utilisateur tape sur une notification (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM] Notification ouverte: ${message.notification?.title}');
      // TODO: Navigation vers la page appropriée selon message.data
    });
  }

  /// Afficher une notification locale (quand l'app est au premier plan)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: message.data['type'] == 'call', // Important pour les appels
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Enregistrer le token FCM auprès du backend
  Future<void> _registerToken(String fcmToken) async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) {
        debugPrint('⚠️ [FCM] Pas de token auth, impossible d\'enregistrer');
        return;
      }

      await _dio.post(
        '/device-tokens',
        data: {
          'token': fcmToken,
          'platform': _getPlatform(),
        },
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      debugPrint('✅ [FCM] Token enregistré auprès du backend');
    } catch (e) {
      debugPrint('❌ [FCM] Erreur enregistrement token: $e');
    }
  }

  /// Supprimer le token FCM (à appeler lors de la déconnexion)
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
        debugPrint('✅ [FCM] Token supprimé du backend');
      }

      _initialized = false;
    } catch (e) {
      debugPrint('❌ [FCM] Erreur suppression token: $e');
    }
  }

  /// Détecter la plateforme
  String _getPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
