import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket;
  final _storage = SecureStorageService();
  
  final Map<String, bool> _onlineUsers = {};

  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé. Appelez connect() d'abord.");
    return _socket!;
  }

  bool get isConnected => _socket?.connected ?? false;

  bool isUserOnline(String userId) => _onlineUsers[userId] ?? false;

  Future<void> connect(String userId) async {
    final token = await _storage.getToken();
    // Le serveur attend une room préfixée par 'user_'
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

    debugPrint("🔵 Initialisation Socket pour l'utilisateur: $userId");
    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .setReconnectionAttempts(10)
        .setReconnectionDelay(2000)
        .setAuth({'token': token})
        .build()
    );

    _socket!.onConnect((_) {
      debugPrint('🟢 Connected to socket');
      _socket!.emit('join', roomName);
    });
    
    _socket!.onReconnect((_) {
      debugPrint('🔄 Reconnected, re-joining room: $roomName');
      _socket!.emit('join', roomName);
    });

    _socket!.onConnectError((error) => debugPrint('❌ Socket error: $error'));

    _socket!.on('user_online', (data) {
      final uId = data['userId']?.toString();
      final online = data['online'] == true;
      if (uId != null) {
        _onlineUsers[uId] = online;
      }
    });

    if (!_socket!.connected) _socket!.connect();
  }

  void joinRoom(String roomId) {
    if (_socket != null && _socket!.connected) {
      // S'assurer que le roomId est aussi au bon format si nécessaire
      _socket!.emit('join', roomId);
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  VoidCallback onTyping(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return () {};
    final handler = (data) => callback(Map<String, dynamic>.from(data));
    _socket!.on('user_typing', handler);
    return () => _socket?.off('user_typing', handler);
  }

  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return () {};

    final handler = (data) => callback(Map<String, dynamic>.from(data));

    _socket!.on('new_message', handler);
    _socket!.on('new_request', handler);
    _socket!.on('request_accepted', (data) => callback({'type': 'request_accepted', ...Map<String, dynamic>.from(data)}));
    _socket!.on('message_read', (data) => callback({'type': 'message_read', ...Map<String, dynamic>.from(data)}));

    return () {
      _socket?.off('new_message', handler);
      _socket?.off('new_request', handler);
      _socket?.off('request_accepted');
      _socket?.off('message_read');
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