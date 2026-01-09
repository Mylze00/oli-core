import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../auth_controller.dart'; 
import '../secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  late IO.Socket socket;
  final _storage = SecureStorageService();

  Future<void> connect() async {
    final token = await _storage.getToken();
    
    socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders(token != null ? {'Authorization': 'Bearer $token'} : {}) // Auth Headers
          .build(),
    );

    socket.connect();

    socket.onConnect((_) async {
      print('🟢 Connected to socket');
      // Pour l'instant on fait confiance au client pour le room join, 
      // idéalement le serveur le fait via le token.
      // On va récupérer l'ID user depuis le token ou profile... 
      // Simplification: On attend que le UI l'appelle ou on le passe en param.
    });

    socket.onDisconnect((_) => print('🔴 Disconnected'));
  }

  void joinRoom(String userId) {
    if (socket.connected) {
      socket.emit('join', userId);
    } else {
      socket.onConnect((_) => socket.emit('join', userId));
    }
  }

  // Not used in REST-based chat (we use API to send), but kept just in case
  void sendMessageViaSocket({
    required String from,
    required String to,
    required String message,
  }) {
    socket.emit('send_message', {
      'from': from,
      'to': to,
      'message': message,
    });
  }

  void onMessage(Function(Map<String, dynamic>) callback) {
    socket.on('new_message', (data) {
      callback(Map<String, dynamic>.from(data));
    });
    
    socket.on('new_request', (data) {
       // Gérer les nouvelles demandes d'amis
       print("New friend request received");
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}
