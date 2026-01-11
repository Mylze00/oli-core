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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider(widget.otherId).notifier)
         .loadMessages(
           productId: widget.productId,
           conversationId: widget.conversationId,
         );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Scroll vers le bas car la liste est inversée dans l'UI habituelle de chat
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    final chatState = ref.watch(chatControllerProvider(widget.otherId));
    final chatCtrl = ref.read(chatControllerProvider(widget.otherId).notifier);
    final theme = Theme.of(context);

    // Auto-scroll si nouveau message
    ref.listen(chatControllerProvider(widget.otherId), (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        // Optionnel : ne scroller que si on est déjà en bas
      }
    });

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
                    reverse: true, // IMPORTANT: Liste inversée pour chat
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chatState.messages.length + 1, // +1 pour le header produit
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
          if (chatState.friendshipStatus == 'pending')
             _buildAcceptanceBanner(chatState, theme),
          if (chatState.error != null)
             _buildErrorBanner(chatState.error!, theme),
          if (_replyMessage != null) _buildReplyPreview(theme),
          if (_shouldShowInput(chatState))
            _buildInputBar(context, chatCtrl, chatState, theme),
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
        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAcceptanceBanner(ChatState state, ThemeData theme) {
    // Correction : Conversion explicite en String pour la comparaison
    final bool isRequester = state.requesterId.toString() == widget.myId.toString();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: isRequester ? Colors.blue[50] : Colors.orange[50],
      child: isRequester 
        ? const Text(
            "En attente d'acceptation par le destinataire...",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
          )
        : Column(
            children: [
              const Text(
                "Accepter cette discussion ?",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => ref.read(chatControllerProvider(widget.otherId).notifier).acceptConversation(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: const Text("Accepter"),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Plus tard", style: TextStyle(color: Colors.black54)),
                  )
                ],
              )
            ],
          ),
    );
  }

  bool _shouldShowInput(ChatState state) {
    // Masquer l'input uniquement si je suis le demandeur et que c'est encore pending
    // (Selon votre logique métier souhaitée)
    if (state.friendshipStatus == 'pending' && state.requesterId.toString() == widget.myId.toString() && state.messages.isNotEmpty) {
      // return false; // Décommentez si vous voulez bloquer l'envoi de messages supplémentaires
    }
    return true;
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
      ],
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, 
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[100],
            ),
            child: widget.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(widget.productImage!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName ?? 'Produit', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                ),
                const SizedBox(height: 2),
                Text(
                  "${widget.productPrice} \$", 
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13)
                ),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
               CircleAvatar(
                 radius: 12,
                 backgroundColor: Colors.grey[200],
                 child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
               ),
               const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? theme.colorScheme.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg['reply_to_content'] != null) 
                      _buildReplyBadge(msg['reply_to_content'], theme, isMe),
                    
                    if (isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          msg['content'],
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                        ),
                      )
                    else 
                      Text(
                        msg['content'] ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBadge(String content, ThemeData theme, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMe ? Colors.white : theme.colorScheme.primary, width: 4)),
      ),
      child: Text(
        content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Réponse à", style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                Text(_replyMessage!['content'] ?? 'Message', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close), 
            onPressed: () => setState(() => _replyMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatController chatCtrl, ChatState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.camera_alt, color: theme.colorScheme.primary), onPressed: () => _pickImage(chatCtrl)),
            IconButton(icon: const Icon(Icons.monetization_on, color: Colors.green), onPressed: () => _showMoneyDialog(context, chatCtrl)),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 4, minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  if (_messageController.text.trim().isNotEmpty) {
                    chatCtrl.sendMessage(
                      content: _messageController.text,
                      replyToId: _replyMessage?['id'],
                      productId: widget.productId,
                      metadata: (state.messages.isEmpty && widget.productId != null) ? {
                        'product_name': widget.productName,
                        'product_price': widget.productPrice,
                        'product_image': widget.productImage,
                      } : null,
                    );
                    _messageController.clear();
                    setState(() => _replyMessage = null);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoneyDialog(BuildContext context, ChatController chatCtrl) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Envoyer Cash"),
        content: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "\$")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(onPressed: () {
            final val = double.tryParse(amountCtrl.text);
            if (val != null) {
              chatCtrl.sendMessage(content: 'Paiement', type: 'money', amount: val);
            }
            Navigator.pop(context);
          }, child: const Text("Confirmer")),
        ],
      ),
    );
  }
}