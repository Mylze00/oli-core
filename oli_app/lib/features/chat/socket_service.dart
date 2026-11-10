import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../main.dart';
import 'call_screen.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket;
  final _storage = SecureStorageService();
  bool _isConnected = false;
  Future<void>? _connecting;
  
  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé.");
    return _socket!;
  }

  bool get isConnected => _isConnected;

  /// Des appels simultanés partagent la même connexion au lieu d'ouvrir deux sockets.
  Future<void> connect(String userId) {
    return _connecting ??= _connect(userId).whenComplete(() => _connecting = null);
  }

  Future<void> _connect(String userId) async {
    final token = await _storage.getToken();
    // CRUCIAL : Doit correspondre à io.to(`user_${recipientId}`) du serveur
    final roomName = "user_$userId"; 
    
    if (_socket != null) {
      if (_socket!.connected) {
        debugPrint("🟡 Socket déjà connecté, rejoint la room: $roomName");
        _socket!.emit('join', roomName);
        return;
      }
      _socket!.connect();
      return;
    }

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .setAuth({'token': token})
        .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('🟢 Connecté au socket. Room: $roomName');
      _socket!.emit('join', roomName);
    });
    
    _socket!.onReconnect((_) {
      _isConnected = true;
      _socket!.emit('join', roomName);
      for (final listener in _reconnectListeners.toList()) {
        listener();
      }
    });
    
    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 Socket déconnecté');
    });
    
    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('❌ Erreur Socket: $err');
    });

    // Ecoute des messages entrants
    _socket!.on('new_message', (data) => _onMessageReceived(data));
    
    // Ecoute des notifications entrantes
    _socket!.on('new_notification', (data) => _onNotificationReceived(data));
    
    // Ecoute des changements de statut (online/offline) — handler séparé (#9)
    // Ecoute des changements de statut (online/offline) — handler séparé (#9)
    _socket!.on('user_online', (data) {
       debugPrint("👤 Statut utilisateur changé: $data");
       _onStatusChanged(data);
    });

    // Ecoute des indicateurs de frappe (typing)
    _socket!.on('user_typing', (data) {
       _onUserTyping(data);
    });

    // --- WebRTC Incoming Call ---
    _socket!.on('webrtc_call_incoming', (data) {
      if (data is Map) {
        debugPrint("📞 APPEL ENTRANT REÇU: $data");
        final context = globalNavigatorKey.currentContext;
        if (context != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                otherId: data['fromId']?.toString() ?? data['callerId']?.toString() ?? '',
                otherName: data['callerName']?.toString() ?? 'Utilisateur',
                otherAvatarUrl: data['callerAvatar']?.toString(),
                isVideoCall: data['type'] == 'video',
                isIncoming: true,
                conversationId: data['conversationId']?.toString(),
              ),
            ),
          );
        }
      }
    });

    _socket!.on('webrtc_call_accept', (data) => _onCallAccepted(data));
    // The server relays 'webrtc_call_accepted' now
    _socket!.on('webrtc_call_accepted', (data) => _onCallAccepted(data));
    _socket!.on('webrtc_call_reject', (data) => _onCallRejected(data));
    _socket!.on('webrtc_call_rejected', (data) => _onCallRejected(data));
    _socket!.on('webrtc_call_cancel', (data) => _onCallCancelled(data));
    _socket!.on('webrtc_call_cancelled', (data) => _onCallCancelled(data));
    _socket!.on('webrtc_call_ended', (data) => _onCallEnded(data));

    // WebRTC Signaling
    _socket!.on('webrtc_offer', (data) => _onWebrtcOffer(data));
    _socket!.on('webrtc_answer', (data) => _onWebrtcAnswer(data));
    _socket!.on('webrtc_ice_candidate', (data) => _onWebrtcIceCandidate(data));
  }

  // Callbacks spécifiques pour l'appel (peuvent être enregistrés par CallScreen)
  Function(Map<String, dynamic>)? _callAcceptHandler;
  Function(Map<String, dynamic>)? _callRejectHandler;
  static const _pendingBlockedCallLifetime = Duration(seconds: 30);
  Map<String, dynamic>? _pendingBlockedCall;
  DateTime? _pendingBlockedCallAt;
  Function(Map<String, dynamic>)? _callCancelHandler;
  Function(Map<String, dynamic>)? _callEndHandler;
  
  // WebRTC Signaling callbacks
  Function(Map<String, dynamic>)? _webrtcOfferHandler;
  Function(Map<String, dynamic>)? _webrtcAnswerHandler;
  Function(Map<String, dynamic>)? _webrtcIceCandidateHandler;


  VoidCallback onCallAccepted(Function(Map<String, dynamic>) callback) {
    _callAcceptHandler = callback;
    return () => _callAcceptHandler = null;
  }
  VoidCallback onCallRejected(Function(Map<String, dynamic>) callback) {
    _callRejectHandler = callback;

    // L'appel part avant l'ouverture de l'écran : le refus peut déjà être arrivé
    final pending = _pendingBlockedCall;
    final receivedAt = _pendingBlockedCallAt;
    _pendingBlockedCall = null;
    _pendingBlockedCallAt = null;
    if (pending != null && receivedAt != null && DateTime.now().difference(receivedAt) < _pendingBlockedCallLifetime) {
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(pending));
    }
    return () => _callRejectHandler = null;
  }
  VoidCallback onCallCancelled(Function(Map<String, dynamic>) callback) {
    _callCancelHandler = callback;
    return () => _callCancelHandler = null;
  }
  VoidCallback onCallEnded(Function(Map<String, dynamic>) callback) {
    _callEndHandler = callback;
    return () => _callEndHandler = null;
  }
  
  VoidCallback onWebrtcOffer(Function(Map<String, dynamic>) callback) {
    _webrtcOfferHandler = callback;
    return () => _webrtcOfferHandler = null;
  }
  VoidCallback onWebrtcAnswer(Function(Map<String, dynamic>) callback) {
    _webrtcAnswerHandler = callback;
    return () => _webrtcAnswerHandler = null;
  }
  VoidCallback onWebrtcIceCandidate(Function(Map<String, dynamic>) callback) {
    _webrtcIceCandidateHandler = callback;
    return () => _webrtcIceCandidateHandler = null;
  }

  void _onCallAccepted(dynamic data) {
    if (_callAcceptHandler != null && data is Map) _callAcceptHandler!(Map<String, dynamic>.from(data));
  }
  void _onCallRejected(dynamic data) {
    if (data is! Map) return;
    final rejection = Map<String, dynamic>.from(data);
    if (_callRejectHandler != null) {
      _callRejectHandler!(rejection);
    } else if (rejection['reason'] == 'blocked') {
      _pendingBlockedCall = rejection;
      _pendingBlockedCallAt = DateTime.now();
    }
  }
  void _onCallCancelled(dynamic data) {
    if (_callCancelHandler != null && data is Map) _callCancelHandler!(Map<String, dynamic>.from(data));
  }
  void _onCallEnded(dynamic data) {
    if (_callEndHandler != null && data is Map) _callEndHandler!(Map<String, dynamic>.from(data));
  }
  void _onWebrtcOffer(dynamic data) {
    if (_webrtcOfferHandler != null && data is Map) _webrtcOfferHandler!(Map<String, dynamic>.from(data));
  }
  void _onWebrtcAnswer(dynamic data) {
    if (_webrtcAnswerHandler != null && data is Map) _webrtcAnswerHandler!(Map<String, dynamic>.from(data));
  }
  void _onWebrtcIceCandidate(dynamic data) {
    if (_webrtcIceCandidateHandler != null && data is Map) _webrtcIceCandidateHandler!(Map<String, dynamic>.from(data));
  }

  // Callbacks séparés pour messages et statuts (#9)
  final _messageListeners = <Function(Map<String, dynamic>)>{};
  final _typingListeners = <Function(Map<String, dynamic>)>{};
  final _reconnectListeners = <VoidCallback>{};
  Function(Map<String, dynamic>)? _statusHandler;
  Function(Map<String, dynamic>)? _notificationHandler;

  /// Enregistrer un callback pour les messages reçus
  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    _messageListeners.add(callback);
    return () => _messageListeners.remove(callback);
  }

  /// Enregistrer un callback pour les changements de statut utilisateur
  VoidCallback onUserStatus(Function(Map<String, dynamic>) callback) {
    _statusHandler = callback;
    return () => _statusHandler = null;
  }
  
  /// Enregistrer un callback pour les notifications
  VoidCallback onNotification(Function(Map<String, dynamic>) callback) {
    _notificationHandler = callback;
    return () => _notificationHandler = null;
  }
  
  /// Enregistrer un callback pour l'indicateur de frappe
  VoidCallback onUserTyping(Function(Map<String, dynamic>) callback) {
    _typingListeners.add(callback);
    return () => _typingListeners.remove(callback);
  }

  /// Après une coupure, les événements manqués doivent être rechargés.
  VoidCallback onReconnected(VoidCallback callback) {
    _reconnectListeners.add(callback);
    return () => _reconnectListeners.remove(callback);
  }
  
  // Generic handler for other events
  void on(String event, Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on(event, (data) {
        if (data is Map) {
           callback(Map<String, dynamic>.from(data));
        } else {
           callback(data);
        }
      });
    }
  }

  void _onMessageReceived(dynamic data) {
    final message = Map<String, dynamic>.from(data);
    for (final listener in _messageListeners.toList()) {
      listener(message);
    }
  }

  void _onStatusChanged(dynamic data) {
    if (_statusHandler != null && data is Map) {
      _statusHandler!(Map<String, dynamic>.from(data));
    }
  }

  void _onNotificationReceived(dynamic data) {
    if (_notificationHandler != null && data is Map) {
      _notificationHandler!(Map<String, dynamic>.from(data));
    }
  }

  void _onUserTyping(dynamic data) {
    if (data is! Map) return;
    final typing = Map<String, dynamic>.from(data);
    for (final listener in _typingListeners.toList()) {
      listener(typing);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    debugPrint("🔌 Socket déconnecté manuellement");
  }

  void emit(String event, dynamic data) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    }
  }
}