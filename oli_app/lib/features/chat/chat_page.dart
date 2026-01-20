import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'dart:convert';
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String myId;
  final String otherId;
  final String otherName;
  final String? productId;
  final String? productName;
  final double? productPrice;
  final String? productImage;

  const ChatPage({
    super.key,
    required this.myId,
    required this.otherId,
    required this.otherName,
    this.productId,
    this.productName,
    this.productPrice,
    this.productImage,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      controller.loadMessages(productId: widget.productId);
    });
  }

  @override
  void dispose() {
    messageCtrl.dispose();
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

    ref.listen(chatControllerProvider(widget.otherId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherName),
            if (widget.productName != null)
              Text(
                widget.productName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.productImage != null || widget.productName != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (widget.productImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.productImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName ?? 'Produit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (widget.productPrice != null)
                          Text(
                            '${widget.productPrice!.toStringAsFixed(0)} FC',
                            style: TextStyle(color: theme.primaryColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_isUploading)
            const LinearProgressIndicator(),

          Expanded(
            child: chatState.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : chatState.error != null
                ? Center(child: Text("Erreur: ${chatState.error}"))
                : chatState.messages.isEmpty
                  ? const Center(child: Text("Aucun message. Commencez la conversation !"))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        final isMe = msg['sender_id'].toString() == widget.myId;
                        
                        // Extraction Metadata
                        String? mediaUrl;
                        if (msg['metadata'] != null) {
                           try {
                             final meta = msg['metadata'] is String 
                                 ? jsonDecode(msg['metadata']) 
                                 : msg['metadata'];
                             mediaUrl = meta['mediaUrl'];
                           } catch (e) { /* ignore */ }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? theme.primaryColor : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (mediaUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          mediaUrl,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c,e,s) => const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  if (msg['content'] != null && msg['content'].toString().isNotEmpty && msg['content'] != '📷 Image')
                                    Text(
                                      msg['content'],
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                   IconButton(
                    icon: Icon(Icons.add_circle, color: theme.primaryColor, size: 28),
                    onPressed: () => _showChatTools(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Votre message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La localisation est désactivée')));
         return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obtention de la position...')));
      
      Position position = await Geolocator.getCurrentPosition();
      final String mapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Outils", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolItem(Icons.attach_money, "Envoyer Cash", Colors.green, () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Fonctionnalité Cash bientôt disponible !")),
                    );
                  }),
                  _buildToolItem(Icons.photo, "Galerie", Colors.purple, () {
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
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _sendMessage() {
    final msg = messageCtrl.text.trim();
    if (msg.isEmpty) return;

    final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
    controller.sendMessage(
      content: msg,
      productId: widget.productId,
      productName: widget.productName,
      productImage: widget.productImage,
      productPrice: widget.productPrice,
    );
    
    messageCtrl.clear();
  }
}