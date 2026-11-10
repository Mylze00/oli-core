import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';

const _permissionsAskedKey = 'call_permissions_asked';
const _ringDurationMs = 45000;

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> _declineCall(CallKitParams params) async {
  final callerId = params.extra?['callerId']?.toString();
  if (callerId == null || callerId.isEmpty) return;

  try {
    final token = await SecureStorageService().getToken();
    await Dio().post(
      '${ApiConfig.baseUrl}/calls/$callerId/decline',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  } catch (e) {
    debugPrint('Refus de l\'appel non transmis: $e');
  }
}

/// Reçoit « Refuser » même quand l'application est fermée.
@pragma('vm:entry-point')
Future<void> nativeCallBackgroundHandler(CallEvent event) async {
  if (event is CallEventActionCallDecline) await _declineCall(event.callKitParams);
}

/// Écran d'appel du système Android : il sonne avec la sonnerie du téléphone, application fermée.
class NativeCallService {
  NativeCallService._();

  static bool get isSupported => _isAndroid;

  /// Un identifiant stable permet d'arrêter la sonnerie quand l'appelant raccroche.
  static String callIdFor(String callerId) => '00000000-0000-4000-8000-${callerId.padLeft(12, '0')}';

  static Map<String, String> _callData(CallKitParams params) => {
        'callerId': params.extra?['callerId']?.toString() ?? '',
        'callerName': params.extra?['callerName']?.toString() ?? 'Utilisateur OLI',
        'callerAvatar': params.extra?['callerAvatar']?.toString() ?? '',
        'callType': params.extra?['callType']?.toString() ?? 'audio',
        'conversationId': params.extra?['conversationId']?.toString() ?? '',
      };

  static Future<void> showIncoming(Map<String, dynamic> data) async {
    final callerId = data['caller_id']?.toString() ?? '';
    final callerName = data['caller_name']?.toString() ?? 'Utilisateur OLI';
    final callerAvatar = data['caller_avatar']?.toString() ?? '';
    final callType = data['call_type']?.toString() ?? 'audio';

    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: callIdFor(callerId),
      nameCaller: callerName,
      appName: 'Oli',
      avatar: callerAvatar,
      handle: callType == 'video' ? 'Appel vidéo' : 'Appel audio',
      type: callType == 'video' ? 1 : 0,
      duration: _ringDurationMs,
      extra: {
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'callType': callType,
        'conversationId': data['conversation_id']?.toString() ?? '',
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Appel manqué',
        callbackText: 'Rappeler',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B1727',
        actionColor: '#34C759',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Appels entrants',
        missedCallNotificationChannelName: 'Appels manqués',
        isShowFullLockedScreen: true,
        textAccept: 'Décrocher',
        textDecline: 'Refuser',
      ),
    ));
  }

  static Future<void> endForCaller(String callerId) async {
    if (_isAndroid) await FlutterCallkitIncoming.endCall(callIdFor(callerId));
  }

  /// [onAccepted] ouvre l'écran d'appel dans l'application.
  static Future<void> listen(void Function(Map<String, String> callData) onAccepted) async {
    if (!_isAndroid) return;

    await FlutterCallkitIncoming.onBackgroundMessage(nativeCallBackgroundHandler);
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event is CallEventActionCallAccept) {
        onAccepted(_callData(event.callKitParams));
      } else if (event is CallEventActionCallDecline) {
        _declineCall(event.callKitParams);
      }
    });

    // « Décrocher » peut avoir lancé l'application, avant que l'écoute ne commence
    final calls = await FlutterCallkitIncoming.activeCalls();
    for (final call in calls) {
      if (call.isAccepted) onAccepted(_callData(call));
    }
  }

  /// L'écran plein d'appel exige ces autorisations sur les versions récentes d'Android.
  static Future<void> requestPermissionsOnce() async {
    if (!_isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionsAskedKey) == true) return;
    await prefs.setBool(_permissionsAskedKey, true);

    await FlutterCallkitIncoming.requestNotificationPermission({
      'title': 'Notifications',
      'rationaleMessagePermission': 'Oli a besoin des notifications pour faire sonner vos appels.',
      'postNotificationMessageRequired': 'Autorisez les notifications dans les réglages pour recevoir vos appels.',
    });
    if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    }
  }
}
