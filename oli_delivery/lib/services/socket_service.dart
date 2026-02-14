import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/config/api_config.dart';
import '../core/providers/storage_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});

class SocketService {
  final Ref _ref;
  IO.Socket? _socket;
  final Map<String, Function> _eventHandlers = {};

  SocketService(this._ref);

  IO.Socket get socket {
    if (_socket == null) throw Exception("Socket non initialisé");
    return _socket!;
  }

  Future<void> connect(String userId) async {
    if (_socket != null) {
      if (_socket!.connected) {
        debugPrint("🟡 Socket déjà connecté");
        return;
      }
      _socket!.connect();
      return;
    }

    // Récupérer le token
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: 'auth_token');

    if (token == null) {
      debugPrint("❌ Pas de token disponible pour Socket.IO");
      return;
    }

    final userRoom = "user_$userId";

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': 'Bearer $token'})
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('🟢 Connecté au socket');
      _socket!.emit('join', userRoom);
      
      // Re-attach event handlers on reconnect
      _eventHandlers.forEach((event, handler) {
        _socket!.on(event, (data) => handler(data));
      });
    });

    _socket!.onReconnect((_) {
      debugPrint('🔄 Socket reconnecté');
      _socket!.emit('join', userRoom);
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔴 Socket déconnecté');
    });

    _socket!.onConnectError((err) {
      debugPrint('❌ Erreur Socket: $err');
    });

    _socket!.connect();
  }

  void on(String event, Function handler) {
    _eventHandlers[event] = handler;
    if (_socket != null) {
      _socket!.on(event, (data) => handler(data));
    } else {
      debugPrint('⏳ Handler pour "$event" enregistré (sera attaché à la connexion)');
    }
  }

  void off(String event) {
    _eventHandlers.remove(event);
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _eventHandlers.clear();
    _socket?.disconnect();
    debugPrint("🔌 Socket déconnecté manuellement");
  }
}
