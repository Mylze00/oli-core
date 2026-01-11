import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/user/user_provider.dart';
import 'socket_service.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final _storage = SecureStorageService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _conversations = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
  // Pour nettoyer l'écouteur du socket à la fermeture
  VoidCallback? _socketCleanup;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    
    // Configuration du Socket après le premier rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocketListener();
    });
  }

  void _setupSocketListener() {
    final socketService = ref.read(socketServiceProvider);
    
    // On s'assure d'être connecté
    final user = ref.read(userProvider).value;
    if (user != null) {
      socketService.connect(user.id.toString());
    }

    // Écoute des messages entrants pour mise à jour locale
    _socketCleanup = socketService.onMessage((data) {
      if (data['conversation_id'] != null || data['conversationId'] != null) {
        _onNewMessageReceived(data);
      } else if (data['type'] == 'new_request') {
        // Pour une toute nouvelle requête, on recharge tout
        _fetchConversations();
      }
    });
  }

  /// Met à jour la liste localement sans rappeler l'API (Gain de performance + Instantanéité)
  void _onNewMessageReceived(Map<String, dynamic> data) {
    if (!mounted) return;

    final myId = ref.read(userProvider).value?.id.toString();
    final convId = (data['conversation_id'] ?? data['conversationId']).toString();
    final senderId = (data['sender_id'] ?? data['senderId']).toString();

    setState(() {
      // 1. Chercher si la conversation existe déjà dans la liste
      int index = _conversations.indexWhere((c) => c['conversation_id'].toString() == convId);

      if (index != -1) {
        // A. La conversation existe : on la met à jour et on la déplace en haut
        final updatedConv = Map<String, dynamic>.from(_conversations[index]);
        
        updatedConv['last_message'] = data['content'];
        updatedConv['last_time'] = data['created_at'] ?? DateTime.now().toIso8601String();
        updatedConv['last_sender_id'] = senderId; // Pour savoir si c'est moi ou l'autre

        // Incrémenter le compteur non-lu si ce n'est pas moi qui ai envoyé le message
        if (senderId != myId) {
          int currentCount = int.tryParse(updatedConv['unread_count']?.toString() ?? '0') ?? 0;
          updatedConv['unread_count'] = currentCount + 1;
        }

        // Suppression ancienne position et insertion en tête
        _conversations.removeAt(index);
        _conversations.insert(0, updatedConv);
        
      } else {
        // B. Nouvelle conversation inconnue : on recharge depuis le serveur pour avoir les infos profile/produit
        _fetchConversations();
      }
    });
  }

  @override
  void dispose() {
    _socketCleanup?.call();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    final token = await _storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _conversations = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint("Erreur API Conversations: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Erreur loading convers: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final token = await _storage.getToken();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/users?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Erreur search: $e");
    }
  }

  void _openChat({
    required String otherId,
    required String otherName,
    String? otherPhone,
    String? productId,
    String? productName,
    double? productPrice,
    String? productImage,
    String? conversationId,
  }) async {
    final myId = ref.read(userProvider).value?.id.toString();
    if (myId == null) return;

    // Navigation vers la page de Chat
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          myId: myId,
          otherId: otherId,
          otherName: otherName,
          otherPhone: otherPhone,
          productId: productId,
          conversationId: conversationId,
          productName: productName,
          productPrice: productPrice,
          productImage: productImage,
        ),
      ),
    );

    // Au retour, on marque comme lu localement et on rafraîchit
    _fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discussions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
             icon: const Icon(Icons.refresh, color: Colors.black),
             onPressed: _fetchConversations,
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Rechercher un ami...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildConversationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(child: Text("Aucun utilisateur trouvé pour '${_searchController.text}'"));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
            child: user['avatar_url'] == null ? Text(user['name'][0].toUpperCase()) : null,
          ),
          title: Text(user['name']),
          subtitle: const Text("Appuyez pour discuter"),
          onTap: () => _openChat(
            otherId: user['id'].toString(), 
            otherName: user['name'], 
            otherPhone: user['phone']
          ),
        );
      },
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("Aucune discussion", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final hasProduct = conv['product_id'] != null;
        
        // Gestion des messages non lus
        final int unreadCount = int.tryParse(conv['unread_count']?.toString() ?? '0') ?? 0;
        final bool hasUnread = unreadCount > 0;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: conv['other_avatar'] != null ? NetworkImage(conv['other_avatar']) : null,
                child: conv['other_avatar'] == null ? Text(conv['other_name'][0].toUpperCase()) : null,
              ),
              if (hasProduct)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_bag, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  conv['other_name'], 
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasProduct)
                Text(
                  "📦 ${conv['product_name']}",
                  style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                conv['last_message'] ?? 'Démarrer la discussion',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // Gras si message non lu, couleur différente si vide
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                  color: conv['last_message'] != null 
                      ? (hasUnread ? Colors.black87 : Colors.grey[700]) 
                      : Colors.blue,
                ),
              ),
            ],
          ),
          trailing: Text(
             _formatTime(conv['last_time']),
             style: TextStyle(
               fontSize: 11, 
               color: hasUnread ? Colors.green : Colors.grey,
               fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal
             ),
          ),
          onTap: () => _openChat(
            otherId: conv['other_id'].toString(), 
            otherName: conv['other_name'],
            otherPhone: conv['other_phone'],
            productId: conv['product_id']?.toString(),
            productName: conv['product_name'],
            productPrice: double.tryParse(conv['product_price']?.toString() ?? '0'),
            productImage: conv['product_image'],
            conversationId: conv['conversation_id']?.toString(),
          ),
        );
      },
    );
  }
  
  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.day}/${dt.month}";
    }
  }
}