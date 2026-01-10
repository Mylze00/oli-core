import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket;
  final _storage = SecureStorageService();
  
  // Suivi de la présence
  final Map<String, bool> _onlineUsers = {};

  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé. Appelez connect() d'abord.");
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  /// Vérifie si un utilisateur est en ligne
  bool isUserOnline(String userId) => _onlineUsers[userId] ?? false;

  Future<void> connect(String userId) async {
    final token = await _storage.getToken();
    
    if (_socket != null) {
      if (_socket!.connected) {
        debugPrint("🟡 Socket déjà connecté, on rejoint juste la room");
        _socket!.emit('join', userId);
        return;
      }
      _socket!.connect();
      return;
    }

    debugPrint("🔵 Initialisation d'une nouvelle connexion Socket");
    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket']) // Force le WebSocket
        .enableAutoConnect()         // Reconnexion auto
        .setReconnectionAttempts(10)  // Nombre de tentatives
        .setReconnectionDelay(2000)  // Délai entre tentatives (2s)
        .setAuth({'token': token})    // Authentification
        .build()
    );

    _socket!.onConnect((_) {
      debugPrint('🟢 Connected to socket');
      _socket!.emit('join', userId);
    });
    
    _socket!.onReconnect((_) {
      debugPrint('🔄 Reconnected, re-joining room...');
      _socket!.emit('join', userId);
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ Socket connection error: $error');
    });

    // Écouter les événements de présence
    _socket!.on('user_online', (data) {
      final uId = data['userId']?.toString();
      final online = data['online'] == true;
      if (uId != null) {
        _onlineUsers[uId] = online;
        debugPrint('👤 User $uId is ${online ? "online" : "offline"}');
      }
    });

    if (_socket!.connected) {
      _socket!.emit('join', userId);
    } else {
      _socket!.connect();
    }
  }

  void joinRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join', roomId);
    } else if (_socket != null) {
      _socket!.onConnect((_) => _socket!.emit('join', roomId));
    }
  }

  /// Émettre l'indicateur de frappe
  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  /// Écouter les événements de frappe
  VoidCallback onTyping(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return () {};

    final handler = (data) {
      callback(Map<String, dynamic>.from(data));
    };

    _socket!.on('user_typing', handler);
    
    return () {
      _socket?.off('user_typing', handler);
    };
  }

  /// Écouter les messages et événements
  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return () {};

    // Handler new_message
    final messageHandler = (data) {
      debugPrint("📩 New message received via socket");
      callback(Map<String, dynamic>.from(data));
    };

    // Handler new_request
    final requestHandler = (data) {
      debugPrint("👋 New friend request/conversation received via socket");
      if (data['message'] != null) {
        callback(Map<String, dynamic>.from(data['message']));
      } else {
        callback(Map<String, dynamic>.from(data));
      }
    };

    // Handler request_accepted
    final acceptedHandler = (data) {
      debugPrint("🤝 Conversation accepted via socket");
      callback({'type': 'request_accepted', ...Map<String, dynamic>.from(data)});
    };

    // Handler message_read
    final readHandler = (data) {
      debugPrint("✓✓ Message read via socket");
      callback({'type': 'message_read', ...Map<String, dynamic>.from(data)});
    };

    _socket!.on('new_message', messageHandler);
    _socket!.on('new_request', requestHandler);
    _socket!.on('request_accepted', acceptedHandler);
    _socket!.on('message_read', readHandler);

    // Fonction de nettoyage
    return () {
      _socket?.off('new_message', messageHandler);
      _socket?.off('new_request', requestHandler);
      _socket?.off('request_accepted', acceptedHandler);
      _socket?.off('message_read', readHandler);
    };
  }

  void disconnect() {
    _socket?.disconnect();
    _onlineUsers.clear();
  }

  void dispose() {
    disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
