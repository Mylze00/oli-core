import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'chat_controller.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/product_context_header.dart';
import 'widgets/chat_input_area.dart';
import '../../../../widgets/auto_refresh_avatar.dart';

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

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // URL d'avatar (récupéré depuis args ou controller)
  String? _effectiveAvatarUrl;

  @override
  void initState() {
    super.initState();
    _effectiveAvatarUrl = widget.otherAvatarUrl;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      controller.loadMessages(productId: widget.productId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      
      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      final url = await controller.uploadImage(image);

      setState(() => _isUploading = false);

      if (url != null) {
        controller.sendMessage(
          content: "",
          mediaUrl: url,
          mediaType: 'image',
          productId: widget.productId,
          productName: widget.productName,
          productImage: widget.productImage,
          productPrice: widget.productPrice,
        );
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Échec de l'upload")),
           );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("Erreur pickImage: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider(widget.otherId));
    final theme = Theme.of(context);

    // Écouteur pour scroll automatique lors de nouveaux messages
    ref.listen(chatControllerProvider(widget.otherId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        // Petit délai pour laisser le temps à la liste de se construire
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Fond gris clair moderne
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
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
                  style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "En ligne", // TODO: Statut réel via Socket
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black54),
            onPressed: () {}, // TODO
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_bg.png"),
            fit: BoxFit.cover,
            opacity: 0.1, // Légère transparence pour la lisibilité
          ),
        ),
        child: Column(
          children: [
            // En-tête de contexte produit (si présent)
            if (widget.productName != null || widget.productImage != null)
              ProductContextHeader(
                productName: widget.productName,
                productPrice: widget.productPrice,
                productImage: widget.productImage,
              ),

            if (_isUploading)
              const LinearProgressIndicator(minHeight: 2),

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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        final isMe = msg['sender_id'].toString() == widget.myId;
                        
                        return ChatMessageBubble(
                          message: msg,
                          isMe: isMe,
                          otherAvatarUrl: _effectiveAvatarUrl,
                        );
                      },
                    ),
          ),
          
            ChatInputArea(
              onSendMessage: _sendMessage,
              onShowTools: () => _showChatTools(context),
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
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Géolocalisation en cours...')));
      
      Position position = await Geolocator.getCurrentPosition();
      final String mapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      controller.sendMessage(
        content: "📍 Ma position actuelle:\n$mapsUrl",
        productId: widget.productId,
        productName: widget.productName,
        productImage: widget.productImage,
        productPrice: widget.productPrice,
      );
    } catch (e) {
      debugPrint("Erreur shareLocation: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur récupération position')));
    }
  }

  void _showChatTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Partager", 
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildToolItem(Icons.image, "Galerie", Colors.purple, () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  }),
                  _buildToolItem(Icons.camera_alt, "Caméra", Colors.red, () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  }),
                  _buildToolItem(Icons.location_on, "Position", Colors.blue, () {
                    Navigator.pop(ctx);
                    _shareLocation();
                  }),
                  _buildToolItem(Icons.attach_money, "Cash", Colors.green, () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Paiement via Chat bientôt disponible !")),
                    );
                  }),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
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
    );
  }
}
