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
import '../../config/api_config.dart';
import '../../core/router/network/dio_provider.dart';

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
                Text(
                  chatState.isOtherUserTyping 
                      ? "Écrit..." 
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_bg_new.png"),
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
              onAudioRecorded: (path) => _sendAudioMessage(path),
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
      
      Position position = await Geolocator.getCurrentPosition();
      final String mapsUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      controller.sendMessage(
        content: "", // Content empty for location bubble
        type: 'location',
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
                    _showSendCashSheet(context);
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

  Future<void> _sendAudioMessage(String path) async {
    setState(() => _isUploading = true);
    try {
      final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
      
      String? url;
      // Sur le Web, path est vide (''). En réalité sur Web on devrait recevoir un Blob ou des bytes.
      // Le plugin record sur Web ne retourne pas de path.
      // Il faut adapter ChatInputArea pour passer les bytes ou un XFile valide sur le web.
      // Pour ce correctif rapide: on vérifie si le path est une "fake string" vide du web.
      if (path.isEmpty) {
        // TODO: Sur Web, il faut refactoriser pour passer Uint8List depuis ChatInputArea
        // Pour l'instant, signalons qu'on ne peut pas upload sans bytes
        debugPrint("Upload Audio Web non implémenté sans bytes");
        // Solution temporaire: ne rien faire ou simuler
        setState(() => _isUploading = false);
        return;
      }

      // Cas Mobile/Desktop
      final xFile = XFile(path);
      url = await controller.uploadImage(xFile); // Use existing upload logic

      setState(() => _isUploading = false);

      if (url != null) {
        controller.sendMessage(
          content: "🎤 Message vocal",
          mediaUrl: url,
          mediaType: 'audio',
          type: 'audio',
          productId: widget.productId,
          productName: widget.productName,
          productImage: widget.productImage,
          productPrice: widget.productPrice,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("Error sending audio: $e");
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
    );
  }

  void _showSendCashSheet(BuildContext context) {
    final amountController = TextEditingController();
    String selectedCurrency = 'USD';
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.send, color: Colors.green.shade700, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Envoyer du cash',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'vers ${widget.otherName}',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                          return Colors.green.shade100;
                        }
                        return Colors.grey.shade100;
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount input
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: selectedCurrency == 'USD' ? '0.00' : '0',
                      hintStyle: TextStyle(fontSize: 28, color: Colors.grey.shade300),
                      prefixText: selectedCurrency == 'USD' ? '\$ ' : '',
                      suffixText: selectedCurrency == 'FC' ? ' FC' : '',
                      prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                      suffixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (selectedCurrency == 'FC')
                    Text(
                      'Sera converti en USD automatiquement',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                            },
                          );

                          if (response.statusCode == 200) {
                            Navigator.pop(ctx);

                            // Send a special chat message for the transfer
                            final displayAmount = selectedCurrency == 'USD'
                                ? '\$${amount.toStringAsFixed(2)}'
                                : '${amount.toStringAsFixed(0)} FC';

                            final controller = ref.read(chatControllerProvider(widget.otherId).notifier);
                            controller.sendMessage(
                              content: '💸 Envoi de $displayAmount',
                              productId: widget.productId,
                              productName: widget.productName,
                              productImage: widget.productImage,
                              productPrice: widget.productPrice,
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
                          String errorMsg = 'Erreur lors du transfert';
                          if (e.toString().contains('Solde insuffisant')) {
                            errorMsg = 'Solde insuffisant !';
                          }
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
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Transfert sécurisé via Oli Wallet',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
