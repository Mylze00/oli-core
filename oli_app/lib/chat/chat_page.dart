import 'package:flutter/material.dart';
import 'socket_service.dart';

class ChatPage extends StatefulWidget {
  final String myId;
  final String otherId;

  const ChatPage({
    super.key,
    required this.myId,
    required this.otherId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SocketService socketService = SocketService();
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    socketService.connect(widget.myId);

    socketService.onMessage((data) {
      setState(() {
        messages.add(data);
      });
    });
  }

  @override
  void dispose() {
    socketService.disconnect();
    super.dispose();
  }

  void send() {
    if (controller.text.isEmpty) return;

    final msg = controller.text;

    socketService.sendMessage(
      from: widget.myId,
      to: widget.otherId,
      message: msg,
    );

    setState(() {
      messages.add({
        'from': widget.myId,
        'message': msg,
      });
    });

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final isMe =
                    messages[i]['from'] == widget.myId;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blue
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      messages[i]['message'],
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
