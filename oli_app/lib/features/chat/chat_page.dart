import '../../core/theme/oli_glass.dart'; // verre bleu des feuilles d'envoi
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'chat_controller.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/product_context_header.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/reply_preview.dart';
import 'widgets/chat_cart_summary.dart';
import 'widgets/message_actions.dart';
import 'widgets/conversation_context_menu.dart';
import 'chat_theme.dart';
import 'chat_media_page.dart';
import 'contact_info_page.dart';
import '../../core/user/user_provider.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../config/api_config.dart';
import 'package:dio/dio.dart';
import '../../core/theme/oli_colors.dart';
import '../../core/router/network/dio_provider.dart';
import '../cart/providers/cart_provider.dart';
import '../checkout/screens/checkout_page.dart';
import 'call_screen.dart';
import 'socket_service.dart';
import 'providers/inbox_providers.dart';
import '../auth/providers/auth_controller.dart';
import '../wallet/providers/wallet_provider.dart';
class ChatPage extends ConsumerStatefulWidget {
  final String myId;
  final String otherId;
  final String otherName;
  final String? productId; // ID optionnel pour le contexte
  final String? productName;
  final double? productPrice;
  final String? productImage;
  final String? otherAvatarUrl; // Nouveau paramètre pour l'avatar dans le header/bulles

  const ChatPage({
    super.key,
    required this.myId,
    required this.otherId,
    required this.otherName,
    this.productId,
    this.productName,
    this.productPrice,
    this.productImage,
    this.otherAvatarUrl,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  ChatController? _chatController;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // URL d'avatar (récupéré depuis args ou controller)
  String? _effectiveAvatarUrl;

  // Swipe-to-reply state
  Map<String, dynamic>? _replyToMessage;

  // Recherche dans la discussion (null = pas de recherche en cours)
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _menuButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _effectiveAvatarUrl = widget.otherAvatarUrl;
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      _chatController = controller;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      controller.setScreenActive(lifecycle == null || lifecycle == AppLifecycleState.resumed);
      controller.openConversation(productId: widget.productId);
      _scrollToBottom();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _chatController?.setScreenActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController?.setScreenActive(false);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Liste inversée : le dernier échange est en position 0
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      final sent = await ref.read(chatControllerProvider(widget.otherId).notifier).sendImage(
        image,
        productId: widget.productId,
        productName: widget.productName,
        productImage: widget.productImage,
        productPrice: widget.productPrice,
      );

      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec de l'envoi de l'image")),
        );
      }
    } catch (e) {
      debugPrint("Erreur pickImage: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final chatState = ref.watch(chatControllerProvider(widget.otherId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final wallpaper = ref.watch(chatWallpaperProvider(widget.otherId));
    final visibleMessages = _visibleMessages(chatState.messages);

    // Écouteur pour scroll automatique lors de nouveaux messages
    ref.listen(chatControllerProvider(widget.otherId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        // Petit délai pour laisser le temps à la liste de se construire
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? OliChatDarkColors.bar : Colors.white,
        elevation: isDark ? 0 : 1,
        scrolledUnderElevation: isDark ? 0 : null,
        surfaceTintColor: isDark ? Colors.transparent : null,
        leading: IconButton(
          icon: Icon(_searchQuery != null ? Icons.close : Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: _searchQuery != null ? _closeSearch : () => Navigator.pop(context),
        ),
        title: _searchQuery != null ? _buildSearchField(isDark, visibleMessages.length) : Row(
          children: [
            AutoRefreshAvatar(
               avatarUrl: _effectiveAvatarUrl,
               size: 36,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  chatState.isOtherUserTyping 
                      ? (chatState.isOtherUserRecording ? "Enregistre un vocal..." : "Écrit...")
                      : (chatState.isOtherUserOnline ? "En ligne" : "Hors ligne"),
                  style: TextStyle(
                    color: chatState.isOtherUserTyping 
                        ? theme.primaryColor 
                        : (chatState.isOtherUserOnline ? Colors.green : Colors.grey),
                    fontSize: 12,
                    fontWeight: chatState.isOtherUserTyping ? FontWeight.bold : FontWeight.normal
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: _searchQuery != null ? null : [
          // Bouton Appel Audio
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => _openCall(video: false),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.withOpacity(0.18) : Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone, color: Colors.green.shade600, size: 22),
              ),
            ),
          ),
          // Bouton Appel Vidéo
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => _openCall(video: true),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.18) : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam, color: Colors.blue.shade600, size: 24),
              ),
            ),
          ),
          _buildConversationMenu(chatState, isDark),
        ],
      ),
      body: Container(
        decoration: chatWallpaperDecoration(wallpaper, isDark: isDark),
        child: Column(
          children: [
            // En-tête de contexte produit (si présent)
            if (widget.productName != null || widget.productImage != null)
              ProductContextHeader(
                productName: widget.productName,
                productPrice: widget.productPrice,
                productImage: widget.productImage,
                onAddToCart: widget.productId != null ? () {
                  final cartItem = CartItem(
                    productId: widget.productId!,
                    productName: widget.productName ?? 'Produit',
                    price: widget.productPrice ?? 0,
                    imageUrl: widget.productImage,
                    sellerId: widget.otherId,
                    sellerName: widget.otherName,
                  );
                  ref.read(chatCartProvider(widget.otherId).notifier)
                      .addProduct(cartItem);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('"${widget.productName}" ajouté au panier'),
                        ],
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } : null,
                onBuyNow: widget.productId != null ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutPage(
                        directPurchaseItem: CartItem(
                          productId: widget.productId!,
                          productName: widget.productName ?? 'Produit',
                          price: widget.productPrice ?? 0,
                          imageUrl: widget.productImage,
                          sellerId: widget.otherId,
                          sellerName: widget.otherName,
                        ),
                      ),
                    ),
                  );
                } : null,
              ),

            if (_isUploading)
              const LinearProgressIndicator(minHeight: 2),

            if (chatState.ephemeralSeconds != null) _buildEphemeralBanner(chatState.ephemeralSeconds, isDark),

          Expanded(
            child: chatState.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : chatState.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text("Erreur: ${chatState.error}"),
                        TextButton(
                          onPressed: () => ref.read(chatControllerProvider(widget.otherId).notifier).loadMessages(),
                          child: const Text("Réessayer"),
                        )
                      ],
                    ),
                  )
                : _searchQuery != null && visibleMessages.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery!.isEmpty ? 'Tapez un mot à rechercher' : 'Aucun message trouvé',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                : chatState.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade300),
                           const SizedBox(height: 10),
                           Text(
                             "Démarrez la conversation avec ${widget.otherName}",
                             style: TextStyle(color: Colors.grey.shade500),
                           ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      // La discussion s'ouvre sur le dernier échange, sans défilement visible
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: visibleMessages.length,
                      itemBuilder: (context, index) {
                        final msg = visibleMessages[visibleMessages.length - 1 - index];
                        final isMe = msg['sender_id'].toString() == widget.myId;
                        
                        return ChatMessageBubble(
                          message: msg,
                          isMe: isMe,
                          currentUserId: widget.myId,
                          otherAvatarUrl: _effectiveAvatarUrl,
                          myAvatarUrl: ref.watch(userProvider).value?.avatarUrl,
                          onSwipeReply: (message) {
                            setState(() => _replyToMessage = message);
                          },
                          onVoicePlayed: (messageId) => ref
                              .read(chatControllerProvider(widget.otherId).notifier)
                              .markVoicePlayed(messageId),
                          onReact: (messageId, emoji) {
                            ref.read(chatControllerProvider(widget.otherId).notifier)
                                .reactToMessage(messageId, emoji);
                          },
                          onEdit: _editMessage,
                          onDelete: _deleteMessage,
                          onForward: _forwardMessage,
                        );
                      },
                    ),
          ),
          
            // Cart summary (when items have been added)
            ChatCartSummary(conversationId: widget.otherId),

            // Reply Preview (shown when swiping a message)
            if (_replyToMessage != null)
              ReplyPreview(
                replyToMessage: _replyToMessage!,
                currentUserId: widget.myId,
                onCancel: () => setState(() => _replyToMessage = null),
              ),

            ChatInputArea(
              onSendMessage: _sendMessage,
              attachments: _chatAttachments(context),
              onVoiceRecorded: _sendVoice,
              onRecording: (isRecording) =>
                  ref.read(chatControllerProvider(widget.otherId).notifier).sendRecording(isRecording),
              onTyping: (isTyping) {
                 ref.read(chatControllerProvider(widget.otherId).notifier).sendTyping(isTyping);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La localisation est désactivée.')));
         return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission de localisation refusée')));
           return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Localisation définitivement refusée. Activez-la dans les paramètres.')));
         return;
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Géolocalisation en cours...')));
      
      // LocationSettings requis pour Flutter Web (sinon erreur "listening for position updates")
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Précision moyenne = moins de data
          timeLimit: Duration(seconds: 15),
        ),
      );
      final String mapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      controller.sendMessage(
        content: "", // Content empty for location bubble
        type: 'location',
        latitude: position.latitude,
        longitude: position.longitude,
        customMetadata: {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        productId: widget.productId,
        productName: widget.productName,
        productImage: widget.productImage,
        productPrice: widget.productPrice,
      );
    } catch (e) {
      debugPrint("Erreur shareLocation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur récupération position: ${e.toString().split(":").last.trim()}')));
      }
    }
  }

  /// Actions de la conversation ouverte, identiques à celles de la liste.
  Widget _buildConversationMenu(ChatState chatState, bool isDark) {
    return IconButton(
      key: _menuButtonKey,
      tooltip: "Plus d'options",
      icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
      onPressed: () => _openConversationMenu(chatState),
    );
  }

  void _openConversationMenu(ChatState chatState) {
    final box = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final conversationId = chatState.conversationId?.toString();
    final conversations = ref.read(inboxConversationsProvider).value ?? const <Map<String, dynamic>>[];
    final conversation = conversations.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['conversation_id']?.toString() == conversationId,
          orElse: () => null,
        );
    final isFavorite = conversation?['is_favorite'] == true;
    final isArchived = conversation?['is_archived'] == true;

    showAnchoredGlassMenu(
      context: context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      items: [
        ConversationMenuItem(icon: Icons.info_outline, label: 'Infos du contact', onTap: _openContactInfo),
        ConversationMenuItem(icon: Icons.search, label: 'Rechercher', onTap: _startSearch),
        ConversationMenuItem(icon: Icons.photo_library_outlined, label: 'Médias, liens et docs', onTap: _openMedia),
        ConversationMenuItem(
          icon: Icons.palette_outlined,
          label: 'Thème de la discussion',
          onTap: () => showChatWallpaperPicker(context, ref, widget.otherId),
        ),
        ConversationMenuItem(
          icon: Icons.timer_outlined,
          label: 'Messages éphémères',
          submenu: [
            for (final entry in kEphemeralDurations.entries)
              ConversationMenuItem(
                icon: chatState.ephemeralSeconds == entry.value ? Icons.check_circle : Icons.radio_button_unchecked,
                label: ephemeralLabel(entry.value),
                onTap: () => _setEphemeral(entry.key),
              ),
          ],
        ),
        if (conversationId != null) ...[
          ConversationMenuItem(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            label: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onTap: () => _runConversationAction('favorite', conversationId, isFavorite, isArchived),
          ),
          ConversationMenuItem(
            icon: Icons.archive_outlined,
            label: isArchived ? 'Désarchiver' : 'Archiver',
            onTap: () => _runConversationAction('archive', conversationId, isFavorite, isArchived),
          ),
          ConversationMenuItem(
            icon: Icons.delete_outline,
            label: 'Supprimer pour moi',
            isDanger: true,
            onTap: () => _runConversationAction('delete', conversationId, isFavorite, isArchived),
          ),
        ],
      ],
    );
  }

  // ─── Outils du menu ⋮ ─────────────────────────────────────────────────────

  void _openCall({required bool video}) {
    final chatState = ref.read(chatControllerProvider(widget.otherId));
    final conversationId = chatState.conversationId?.toString() ??
        (chatState.messages.isNotEmpty ? chatState.messages.first['conversation_id']?.toString() : null);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(
        otherId: widget.otherId,
        conversationId: conversationId,
        otherName: widget.otherName,
        otherAvatarUrl: _effectiveAvatarUrl,
        isVideoCall: video,
        isIncoming: false,
      ),
    ));
  }

  /// Messages à afficher : sans les éphémères expirés, et filtrés pendant une recherche.
  List<Map<String, dynamic>> _visibleMessages(List<Map<String, dynamic>> messages) {
    final query = _searchQuery?.toLowerCase();
    return messages.where((m) {
      if (isMessageExpired(m)) return false;
      if (query == null) return true;
      if (query.isEmpty || m['deleted_at'] != null) return false;
      return (m['content']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  void _startSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _searchQuery = null);
  }

  Widget _buildSearchField(bool isDark, int resultCount) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: 'Rechercher dans la discussion',
        border: InputBorder.none,
        suffixText: _searchQuery?.isNotEmpty == true ? '$resultCount' : null,
      ),
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
    );
  }

  int _mediaCount(List<Map<String, dynamic>> messages) => messages.where((m) {
        if (m['deleted_at'] != null) return false;
        final raw = m['metadata'];
        final hasMedia = raw is Map ? raw['mediaUrl'] != null : raw?.toString().contains('mediaUrl') == true;
        final content = m['content']?.toString() ?? '';
        return hasMedia || content.contains('http://') || content.contains('https://');
      }).length;

  void _openMedia() {
    final messages = ref.read(chatControllerProvider(widget.otherId)).messages.where((m) => !isMessageExpired(m)).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatMediaPage(otherName: widget.otherName, messages: messages),
    ));
  }

  void _openContactInfo() {
    final messages = ref.read(chatControllerProvider(widget.otherId)).messages;
    Navigator.push(context, MaterialPageRoute(
      builder: (pageContext) => ContactInfoPage(
        otherId: widget.otherId,
        otherName: widget.otherName,
        avatarUrl: _effectiveAvatarUrl,
        mediaCount: _mediaCount(messages),
        onAudioCall: () => _openCall(video: false),
        onVideoCall: () => _openCall(video: true),
        onSearch: _startSearch,
        onOpenMedia: _openMedia,
        onTheme: () => showChatWallpaperPicker(pageContext, ref, widget.otherId),
        onEphemeral: () => _chooseEphemeral(pageContext),
      ),
    ));
  }

  Future<void> _setEphemeral(String durationKey) async {
    final notifier = ref.read(chatControllerProvider(widget.otherId).notifier);
    final error = await notifier.setEphemeral(durationKey);
    final seconds = kEphemeralDurations[durationKey];
    _showResult(error, success: seconds == null
        ? 'Messages éphémères désactivés'
        : 'Les nouveaux messages disparaîtront après ${ephemeralLabel(seconds)}');
  }

  Future<void> _chooseEphemeral(BuildContext sheetContext) async {
    final current = ref.read(chatControllerProvider(widget.otherId)).ephemeralSeconds;
    final choice = await showModalBottomSheet<String>(
      context: sheetContext,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Messages éphémères', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Les nouveaux messages disparaîtront pour vous deux après la durée choisie. Les transferts d\'argent restent.',
                style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).hintColor),
              ),
            ),
            for (final entry in kEphemeralDurations.entries)
              ListTile(
                leading: Icon(
                  current == entry.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: current == entry.value ? Theme.of(ctx).primaryColor : null,
                ),
                title: Text(ephemeralLabel(entry.value)),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (choice != null) await _setEphemeral(choice);
  }

  Widget _buildEphemeralBanner(int? seconds, bool isDark) {
    return GestureDetector(
      onTap: () => _chooseEphemeral(context),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 15, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 6),
            Text(
              'Messages éphémères : ${ephemeralLabel(seconds)}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runConversationAction(String action, String id, bool isFavorite, bool isArchived) async {
    final notifier = ref.read(inboxConversationsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer la conversation'),
          content: const Text('La conversation sera retirée pour vous. Votre interlocuteur garde son historique.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final error = await notifier.deleteForMe(id);
      messenger.showSnackBar(SnackBar(content: Text(error ?? 'Conversation supprimée pour vous')));
      if (error == null) navigator.pop();
      return;
    }

    final String? error = action == 'favorite'
        ? await notifier.setFlags(id, {'is_favorite': !isFavorite})
        : await notifier.setFlags(id, {'is_archived': !isArchived});
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Conversation mise à jour')));
  }

  /// Icônes colorées sur pastilles blanches, comme le panneau de pièces jointes de WhatsApp.
  List<ChatAttachmentOption> _chatAttachments(BuildContext context) => [
        ChatAttachmentOption(
          icon: Icons.photo_library_rounded,
          label: 'Photos',
          color: const Color(0xFF1A8CFF),
          onTap: () => _pickImage(ImageSource.gallery),
        ),
        ChatAttachmentOption(
          icon: Icons.camera_alt_rounded,
          label: 'Caméra',
          color: const Color(0xFF3A3A3C),
          onTap: () => _pickImage(ImageSource.camera),
        ),
        ChatAttachmentOption(
          icon: Icons.location_on_rounded,
          label: 'Localisation',
          color: const Color(0xFF00C48C),
          onTap: _shareLocation,
        ),
        ChatAttachmentOption(
          icon: Icons.payments_rounded,
          label: 'Cash',
          color: const Color(0xFF2EAF4E),
          onTap: () => _showSendCashSheet(context),
        ),
      ];

  // ─── Actions du menu d'un message ─────────────────────────────────────────

  ChatController get _chatNotifier => ref.read(chatControllerProvider(widget.otherId).notifier);

  void _showResult(String? error, {String? success}) {
    final text = error ?? success;
    if (text == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final controller = TextEditingController(text: message['content']?.toString() ?? '');
    final edited = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? OliChatDarkColors.bar : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modifier le message', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Possible pendant ${kMessageEditWindow.inMinutes} minutes après l\'envoi',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enregistrer',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    final id = message['id']?.toString();
    if (edited == null || edited.isEmpty || id == null || edited == message['content']?.toString()) return;
    _showResult(await _chatNotifier.editMessage(id, edited));
  }

  Future<void> _deleteMessage(String messageId, {required bool forAll}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(forAll ? 'Supprimer pour tous ?' : 'Supprimer pour vous ?'),
        content: Text(forAll
            ? 'Le message sera remplacé par « Message supprimé » chez vous et chez ${widget.otherName}.'
            : 'Le message disparaîtra de votre discussion. ${widget.otherName} le verra toujours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5484D)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _showResult(await _chatNotifier.deleteMessage(messageId, forAll: forAll));
  }

  String _forwardPreview(Map<String, dynamic> message) {
    final content = message['content']?.toString() ?? '';
    if (message['type'] == 'location') return '📍 Position partagée';
    final raw = message['metadata'];
    Map<String, dynamic>? metadata;
    try {
      metadata = raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>?;
    } catch (_) {}
    if (metadata?['mediaType'] == 'audio') return '🎤 Message vocal';
    if (metadata?['mediaUrl'] != null && (content.isEmpty || content == '📷 Image')) return '📷 Photo';
    return content;
  }

  void _forwardMessage(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    if (id == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardSheet(
        previewText: _forwardPreview(message),
        currentConversationId: ref.read(chatControllerProvider(widget.otherId)).conversationId?.toString(),
        onForward: (conversationIds) => _chatNotifier.forwardMessage(id, conversationIds),
      ),
    );
  }

  Future<void> _sendVoice(VoiceRecording recording) async {
    final replyToId = _replyToMessage?['id']?.toString();
    setState(() => _replyToMessage = null);

    final sent = await ref.read(chatControllerProvider(widget.otherId).notifier).sendVoice(
      XFile(recording.path, name: recording.fileName, mimeType: recording.mimeType),
      duration: recording.duration,
      waveform: recording.waveform,
      replyToId: replyToId,
      productId: widget.productId,
      productName: widget.productName,
      productImage: widget.productImage,
      productPrice: widget.productPrice,
    );

    if (!sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'envoi du vocal")),
      );
    }
  }

  void _sendMessage(String msg) {
    if (msg.trim().isEmpty) return;

    final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
    controller.sendMessage(
      content: msg,
      productId: widget.productId,
      productName: widget.productName,
      productImage: widget.productImage,
      productPrice: widget.productPrice,
      replyToId: _replyToMessage?['id']?.toString(),
    );

    // Clear reply state
    if (_replyToMessage != null) {
      setState(() => _replyToMessage = null);
    }
  }

  void _showSendCashSheet(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController(); // Added note controller
    String selectedCurrency = 'USD';
    bool isSending = false;
    // Même clé pour toutes les tentatives de cet envoi : jamais débité deux fois.
    final transferKey = newTransferKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Même verre bleu nuit que les feuilles du portefeuille (oli_glass.dart).
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: OliGlassPanel(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OliPalette.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded, color: OliPalette.blue, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Envoyer du cash',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'CreatoDisplay', color: Colors.white),
                            ),
                            Text(
                              'vers ${widget.otherName}',
                              style: const TextStyle(fontSize: 14, color: OliPalette.textSecondary, fontFamily: 'CreatoDisplay'),
                            ),
                            const SizedBox(height: 4),
                            Consumer(
                              builder: (context, ref, child) {
                                final walletState = ref.watch(walletProvider);
                                return Text(
                                  'Solde: ${walletState.balance.toStringAsFixed(0)} FC',
                                  style: const TextStyle(fontSize: 13, color: OliPalette.blueOnDark, fontWeight: FontWeight.w600, fontFamily: 'CreatoDisplay'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Séparateur, comme sous l'en-tête des feuilles du portefeuille
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),

                  // Currency toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'USD', label: Text('USD \$')),
                      ButtonSegment(value: 'FC', label: Text('FC (CDF)')),
                    ],
                    selected: {selectedCurrency},
                    onSelectionChanged: (val) {
                      setSheetState(() => selectedCurrency = val.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return OliPalette.blue;
                        }
                        return Colors.white.withValues(alpha: 0.06);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return OliPalette.textSecondary;
                      }),
                      iconColor: const WidgetStatePropertyAll(Colors.white),
                      side: const WidgetStatePropertyAll(BorderSide(color: OliPalette.hairline)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount input
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    cursorColor: OliPalette.blueOnDark,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: selectedCurrency == 'USD' ? '0.00' : '0',
                      hintStyle: TextStyle(fontSize: 28, color: Colors.white.withValues(alpha: 0.25)),
                      prefixText: selectedCurrency == 'USD' ? '\$ ' : '',
                      suffixText: selectedCurrency == 'FC' ? ' FC' : '',
                      prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: OliPalette.blueOnDark),
                      suffixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: OliPalette.blueOnDark),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: OliPalette.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: OliPalette.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: OliPalette.blueOnDark, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comment field
                  TextField(
                    controller: noteController,
                    style: const TextStyle(fontFamily: 'CreatoDisplay', fontSize: 16, color: Colors.white),
                    cursorColor: OliPalette.blueOnDark,
                    decoration: InputDecoration(
                      hintText: 'Commentaire de commande (Optionnel)',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4), fontFamily: 'CreatoDisplay'),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: OliPalette.blueOnDark, width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.notes, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ),

                  if (selectedCurrency == 'USD')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Converti en FC au taux du jour au moment de l'envoi",
                        style: const TextStyle(fontSize: 12, color: OliPalette.textSecondary, fontFamily: 'CreatoDisplay'),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSending ? null : () async {
                        final amountText = amountController.text.trim();
                        final amount = double.tryParse(amountText);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez entrer un montant valide')),
                          );
                          return;
                        }

                        setSheetState(() => isSending = true);

                        try {
                          final dio = ref.read(dioProvider);
                          final response = await dio.post(
                            ApiConfig.walletTransfer,
                            data: {
                              'receiverId': widget.otherId,
                              'amount': amount,
                              'currency': selectedCurrency,
                              if (noteController.text.trim().isNotEmpty) 'note': noteController.text.trim(),
                            },
                            options: Options(headers: {'Idempotency-Key': transferKey}),
                          );

                          if (response.statusCode == 200) {
                            Navigator.pop(ctx);
                            
                            // Refresh wallet
                            ref.read(walletProvider.notifier).loadWalletData();

                            // Send a special chat message for the transfer
                            // Montant réellement transféré, après conversion au taux du jour
                            final displayAmount = '${(response.data['amountFC'] as num).toStringAsFixed(0)} FC';
                            
                            String messageContent = '💸 Envoi de $displayAmount';
                            if (noteController.text.trim().isNotEmpty) {
                              messageContent += '\nNote: ${noteController.text.trim()}';
                            }

                            final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
                            controller.sendMessage(
                              content: messageContent,
                              productId: widget.productId,
                              productName: widget.productName,
                              productImage: widget.productImage,
                              productPrice: widget.productPrice,
                              // Le serveur vérifie cette référence avant d'afficher le billet
                              customMetadata: {
                                'cash_transfer': {
                                  'reference': response.data['reference'],
                                  'amount_fc': response.data['amountFC'],
                                },
                              },
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Text('$displayAmount envoyé à ${widget.otherName} ✓'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setSheetState(() => isSending = false);
                          final serverError = e is DioException && e.response?.data is Map
                              ? e.response!.data['error']?.toString()
                              : null;
                          final errorMsg = serverError ?? 'Erreur lors du transfert';
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: isSending
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(isSending ? 'Envoi en cours...' : 'Envoyer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OliPalette.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: OliPalette.blue.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'CreatoDisplay'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        'Transfert sécurisé via Oli Wallet',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ],
              ),
              ),
              ),
            );
          },
        );
      },
    );
  }
}
