import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket;
  final _storage = SecureStorageService();
  bool _isConnected = false;
  
  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé.");
    return _socket!;
  }

  bool get isConnected => _isConnected;

  Future<void> connect(String userId) async {
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
    
    // Ecoute des changements de statut (online/offline)
    _socket!.on('user_status', (data) {
       debugPrint("Statut utilisateur changé: $data");
       // On peut réutiliser le handler de message pour invalider, ou juste émettre un event
       // Pour l'instant, on traite ça comme un message pour déclencher le refresh de la liste
       _onMessageReceived(data); 
    });
  }

  // Système de callback pour le controller
  Function(Map<String, dynamic>)? _messageHandler;

  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    _messageHandler = callback;
    return () => _messageHandler = null;
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
    if (_messageHandler != null) {
      _messageHandler!(Map<String, dynamic>.from(data));
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