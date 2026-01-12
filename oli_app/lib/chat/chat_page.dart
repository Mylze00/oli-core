import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; 
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String myId;
  final String otherId;
  final String otherName;
  final String? otherPhone;
  final String? productId;
  final String? conversationId;
  final String? productName;
  final double? productPrice;
  final String? productImage;

  const ChatPage({
    super.key,
    required this.myId,
    required this.otherId,
    this.otherName = 'Chat',
    this.otherPhone,
    this.productId,
    this.conversationId,
    this.productName,
    this.productPrice,
    this.productImage,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _replyMessage;

  @override
  void initState() {
    super.initState();
    // Suppression de loadMessages : Firestore gère le flux en temps réel automatiquement via le provider
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setReply(Map<String, dynamic> message) {
    setState(() => _replyMessage = message);
  }

  Future<void> _pickImage(ChatController chatCtrl) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      chatCtrl.sendMessage(content: pickedFile.path, type: 'image');
    }
  }

  @override
  Widget build(BuildContext context) {
    // On écoute l'état du contrôleur (qui doit être branché sur un Stream Firestore)
    final chatState = ref.watch(chatControllerProvider(widget.otherId));
    final chatCtrl = ref.read(chatControllerProvider(widget.otherId).notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView.builder(
                    reverse: true, 
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chatState.messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == chatState.messages.length) {
                        return _buildProductHeader(theme);
                      }
                      final msg = chatState.messages[index];
                      final isMe = msg['sender_id'].toString() == widget.myId;
                      return _buildMessageBubble(context, msg, isMe);
                    },
                  ),
                ),
          ),
          
          // Affichage des erreurs si besoin
          if (chatState.error != null)
             _buildErrorBanner(chatState.error!, theme),
             
          // Aperçu de la réponse
          if (_replyMessage != null) _buildReplyPreview(theme),
          
          // Barre d'envoi
          _buildInputBar(context, chatCtrl, theme),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.otherName, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(ThemeData theme) {
    if (widget.productId == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          if (widget.productImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(widget.productImage!, width: 50, height: 50, fit: BoxFit.cover),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.productName ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("${widget.productPrice} \$", style: TextStyle(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> msg, bool isMe) {
    final theme = Theme.of(context);
    final isImage = msg['type'] == 'image';
    
    return GestureDetector(
      onHorizontalDragEnd: (_) => _setReply(msg),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? theme.colorScheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isImage
                  ? Image.network(msg['content'], width: 200)
                  : Text(
                      msg['content'] ?? '',
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_replyMessage!['content'] ?? '', maxLines: 1)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatController chatCtrl, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(chatCtrl)),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: theme.colorScheme.primary),
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  chatCtrl.sendMessage(content: _messageController.text);
                  _messageController.clear();
                  setState(() => _replyMessage = null);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}