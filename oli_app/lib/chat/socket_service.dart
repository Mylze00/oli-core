import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../auth_controller.dart'; 
import '../secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  IO.Socket? _socket; // Utiliser un nullable au lieu de late
  final _storage = SecureStorageService();

  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé. Appelez connect() d'abord.");
    return _socket!;
  }

  Future<void> connect(String userId) async {
    final token = await _storage.getToken();
    
    if (_socket != null) {
      if (_socket!.connected) {
        print("🟡 Socket déjà connecté, on rejoint juste la room");
        _socket!.emit('join', userId);
        return;
      }
      // Si existant mais déco, on tente reconnect
      _socket!.connect();
      return;
    }

    print("🔵 Initialisation d'une nouvelle connexion Socket");
    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token}) // Passer ici au lieu des headers pour le Web
          .build(),
    );

    _socket!.onConnect((_) {
      print('🟢 Connected to socket');
      _socket!.emit('join', userId);
    });
    
    // Add robustness for reconnects
    _socket!.onReconnect((_) {
      print('🔄 Reconnected, re-joining room...');
      _socket!.emit('join', userId);
    });

    if (_socket!.connected) {
       _socket!.emit('join', userId);
    } else {
       _socket!.connect();
    }
  }

  void joinRoom(String userId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join', userId);
    } else if (_socket != null) {
      _socket!.onConnect((_) => _socket!.emit('join', userId));
    }
  }

  // Not used in REST-based chat (we use API to send), but kept just in case
  void sendMessageViaSocket({
    required String from,
    required String to,
    required String message,
  }) {
    _socket?.emit('send_message', {
      'from': from,
      'to': to,
      'message': message,
    });
  }

  // Retourne une fonction de nettoyage (dispose) pour retirer les écouteurs
  VoidCallback onMessage(Function(Map<String, dynamic>) callback) {
    if (_socket == null) return () {};

    // Wrapper pour new_message
    final messageHandler = (data) {
      print("📩 New message received via socket");
      callback(Map<String, dynamic>.from(data));
    };

    // Wrapper pour new_request
    final requestHandler = (data) {
       print("👋 New friend request/conversation received via socket");
       if (data['message'] != null) {
         callback(Map<String, dynamic>.from(data['message']));
       } else {
         callback(Map<String, dynamic>.from(data));
       }
    };

    // Wrapper pour request_accepted (Rafraîchir les conversations)
    final acceptedHandler = (data) {
      print("🤝 Conversation accepted via socket");
      callback({'type': 'request_accepted', ...Map<String, dynamic>.from(data)});
    };

    _socket!.on('new_message', messageHandler);
    _socket!.on('new_request', requestHandler);
    _socket!.on('request_accepted', acceptedHandler);

    // Fonction de nettoyage
    return () {
      _socket?.off('new_message', messageHandler);
      _socket?.off('new_request', requestHandler);
      _socket?.off('request_accepted', acceptedHandler);
    };
  }

  void disconnect() {
    _socket?.disconnect();
  }
}
