import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'socket_service.dart';
import '../config/api_config.dart';
import '../secure_storage_service.dart';

class ChatPage extends StatefulWidget {
  final String myId;
  final String otherId;
  final String otherName; // Pour l'AppBar

  const ChatPage({
    super.key,
    required this.myId,
    required this.otherId,
    this.otherName = 'Chat',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SocketService socketService = SocketService();
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final _storage = SecureStorageService();
  
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  String? conversationId;

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _loadMessages();
  }
  
  Future<void> _connectSocket() async {
    await socketService.connect();
    socketService.joinRoom(widget.myId);
    
    socketService.onMessage((data) {
      // Vérifier si le message concerne cette conversation (ou cet expéditeur)
      if (data['sender_id'].toString() == widget.otherId || 
          data['conversation_id'] == conversationId) {
        setState(() {
          messages.add(data);
           _scrollToBottom();
        });
      }
    });
  }

  Future<void> _loadMessages() async {
    final token = await _storage.getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/chat/messages/${widget.otherId}');
    
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          messages = data.map((e) => e as Map<String, dynamic>).toList();
          isLoading = false;
        });
        if (messages.isNotEmpty) {
           conversationId = messages[0]['conversation_id'].toString();
           _scrollToBottom();
        }
      }
    } catch (e) {
      print("Erreur chargement messages: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendMessage({String type = 'text', String? content, double? amount}) async {
    if (content == null && controller.text.trim().isEmpty) return;
    
    final textToSend = content ?? controller.text.trim();
    final token = await _storage.getToken();

    // Optimistic UI Update (facultatif, mais sympa)
    /*
    setState(() {
      messages.add({
        'sender_id': int.parse(widget.myId),
        'content': textToSend,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
    });
    */
    controller.clear();

    // 1. Déterminer si c'est un PREMIER message (Request) ou normal
    // Si messages est vide, c'est une request via /chat/request
    // MAIS, pour simplifier, on peut juste utiliser /chat/messages et laisser le backend gérer ou...
    // Mon backend `chat.routes.js` a `/request` et `/messages`.
    // Il faut savoir si on a un convoId.
    
    final endpoint = (messages.isEmpty && conversationId == null) 
        ? '/chat/request' 
        : '/chat/messages';

    // Body
    final body = {
        'recipientId': widget.otherId,
        'content': textToSend,
        'type': type,
        if (amount != null) 'amount': amount,
        if (conversationId != null) 'conversation_id': conversationId,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final newMsg = jsonDecode(response.body);
        // Si c'était une request, on reçoit { success: true, message: ... }
        final msgData = newMsg['message'] ?? newMsg; 
        
        setState(() {
          // On évite les doublons si on avait fait optimistic UI
          messages.add(msgData);
          if (conversationId == null && msgData['conversation_id'] != null) {
            conversationId = msgData['conversation_id'].toString();
          }
          _scrollToBottom();
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Erreur: ${response.body}")),
         );
      }
    } catch (e) {
       print("Erreur envoi: $e");
    }
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    socketService.disconnect(); // Ou laisser actif si service global
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(widget.otherName[0])),
            const SizedBox(width: 10),
            Text(widget.otherName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : messages.isEmpty 
                  ? const Center(child: Text("Commencez la discussion ! 👋"))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final msg = messages[i];
                        final isMe = msg['sender_id'].toString() == widget.myId;
                        
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[600] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isMe ? Radius.zero : null,
                                bottomLeft: !isMe ? Radius.zero : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg['type'] == 'text')
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                                  ),
                                if (msg['type'] == 'money')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Transfert: ${msg['amount']} \$",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? Colors.white : Colors.black
                                        ),
                                      ),
                                    ],
                                  ),
                                // Timestamp
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(msg['created_at']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.black54
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () {}), // Plus d'options
            IconButton(icon: const Icon(Icons.camera_alt, color: Colors.blue), onPressed: () {}), // Photo
            IconButton(
              icon: const Icon(Icons.attach_money, color: Colors.green), 
              onPressed: () {
                // Show modal to send money
                _showSendMoneyDialog();
              }
            ), 
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
             IconButton(
               // Si texte vide => Micro, sinon => Envoyer
               icon: const Icon(Icons.send, color: Colors.blue),
               onPressed: () => _sendMessage(),
             ),
          ],
        ),
      ),
    );
  }
  
  void _showSendMoneyDialog() {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Envoyer du Cash 💸"),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Montant", suffixText: "\$"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage(type: 'money', content: 'Transfert d\'argent', amount: double.tryParse(amountCtrl.text));
            },
            child: const Text("Envoyer"),
          )
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
