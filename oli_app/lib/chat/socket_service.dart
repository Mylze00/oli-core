import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  void connect(String userId) {
    socket = IO.io(
      'http://10.0.2.2:3000', // Android emulator
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      socket.emit('join', userId);
      print('🟢 Connected to socket');
    });
  }

  void sendMessage({
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
    socket.on('receive_message', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}
