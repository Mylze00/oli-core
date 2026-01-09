import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; 
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String myId;
  final String otherId;
  final String otherName;
  final String? otherPhone; // Nouveau champ
  final String? productId; // Restoré
  final String? conversationId; // Nouveau
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
  
  // État local pour la gestion des réponses (Reply)
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

  // --- LOGIQUE WHATSAPP-LIKE ---

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
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
      // Le controller gère maintenant l'upload quand type='image'
      chatCtrl.sendMessage(content: pickedFile.path, type: 'image');
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider(widget.otherId));
    final chatCtrl = ref.read(chatControllerProvider(widget.otherId).notifier);
    final theme = Theme.of(context);

    // Auto-scroll
    ref.listen(chatControllerProvider(widget.otherId), (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: _buildProductHeader(theme)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final msg = chatState.messages[index];
                            final isMe = msg['sender_id'].toString() == widget.myId;
                            return _buildMessageBubble(context, msg, isMe);
                          },
                          childCount: chatState.messages.length,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
          if (chatState.friendshipStatus == 'pending')
             _buildAcceptanceBanner(chatState, theme),
          if (chatState.error != null)
             _buildErrorBanner(chatState.error!, theme),
          if (_replyMessage != null) _buildReplyPreview(theme),
          if (_shouldShowInput(chatState))
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
        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAcceptanceBanner(ChatState state, ThemeData theme) {
    bool isRequester = state.requesterId == widget.myId;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: isRequester ? theme.colorScheme.primaryContainer.withOpacity(0.3) : Colors.orange[50],
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
    if (state.friendshipStatus == 'pending' && state.requesterId == widget.myId && state.messages.isNotEmpty) {
      return false;
    }
    return true;
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherName, style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
              if (widget.otherPhone != null)
                Text(widget.otherPhone!, style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
              Text("En ligne", style: theme.textTheme.labelSmall?.copyWith(color: Colors.green)),
            ],
          ),
        ],
      ),
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
    );
  }

  Widget _buildProductHeader(ThemeData theme) {
    if (widget.productId == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          if (widget.productImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(widget.productImage!, width: 50, height: 50, fit: BoxFit.cover),
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.productName ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.bold))),
          Text("${widget.productPrice} \$", style: TextStyle(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> msg, bool isMe) {
    final theme = Theme.of(context);
    return GestureDetector(
      onHorizontalDragEnd: (_) => _setReply(msg), // Swipe pour répondre
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary : (Colors.lightBlue[100] ?? theme.colorScheme.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            boxShadow: [
              if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg['reply_to_content'] != null) _buildReplyBadge(msg['reply_to_content'], theme, isMe),
              if (msg['type'] == 'image') 
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg['content'],
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                  ),
                )
              else if (msg['type'] == 'money')
                _buildMoneyContent(msg, isMe)
              else
                Text(
                  msg['content'] ?? '',
                  style: TextStyle(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                ),
              const SizedBox(height: 2),
              Text(
                _formatTime(msg['created_at']), 
                style: TextStyle(fontSize: 9, color: isMe ? theme.colorScheme.onPrimary.withOpacity(0.7) : theme.colorScheme.outline),
              ),
            ],
          ),
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
                Text(_replyMessage!['content'] ?? 'Image', maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildInputBar(BuildContext context, ChatController chatCtrl, ThemeData theme) {
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

  // --- FONCTIONNALITÉS COMPLÉMENTAIRES ---

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

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildMoneyContent(Map<String, dynamic> msg, bool isMe) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.payments, color: isMe ? Colors.white70 : Colors.amber),
      const SizedBox(width: 8),
      Text("Payé: ${msg['amount']}\$", style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black)),
    ]);
  }
}
