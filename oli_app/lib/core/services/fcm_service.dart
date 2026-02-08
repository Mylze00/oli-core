import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Handler pour les messages en arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [FCM] Message reçu en arrière-plan: ${message.notification?.title}');
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

  /// Canal de notification Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'oli_notifications',
    'Notifications Oli',
    description: 'Notifications de l\'application Oli',
    importance: Importance.high,
    playSound: true,
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

      print('🔔 [FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ [FCM] Permission refusée par l\'utilisateur');
        return;
      }

      // 2. Initialiser les notifications locales (pour afficher en foreground)
      await _initLocalNotifications();

      // 3. Récupérer et enregistrer le token
      final token = await _messaging.getToken();
      if (token != null) {
        print('📱 [FCM] Token: ${token.substring(0, 20)}...');
        await _registerToken(token);
      }

      // 4. Écouter le renouvellement du token
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 [FCM] Token renouvelé');
        _registerToken(newToken);
      });

      // 5. Configurer les handlers de messages
      _setupMessageHandlers();

      _initialized = true;
      print('✅ [FCM] Service initialisé');
    } catch (e) {
      print('❌ [FCM] Erreur d\'initialisation: $e');
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
        print('🔔 [FCM] Notification locale tappée: ${response.payload}');
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
      print('🔔 [FCM] Message foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Quand l'utilisateur tape sur une notification (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 [FCM] Notification ouverte: ${message.notification?.title}');
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
          importance: Importance.high,
          priority: Priority.high,
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
        print('⚠️ [FCM] Pas de token auth, impossible d\'enregistrer');
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

      print('✅ [FCM] Token enregistré auprès du backend');
    } catch (e) {
      print('❌ [FCM] Erreur enregistrement token: $e');
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
        print('✅ [FCM] Token supprimé du backend');
      }

      _initialized = false;
    } catch (e) {
      print('❌ [FCM] Erreur suppression token: $e');
    }
  }

  /// Détecter la plateforme
  String _getPlatform() {
    // Simple detection - in production use Platform.isAndroid etc.
    return 'android';
  }
}
