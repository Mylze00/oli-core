import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';
import '../config/api_config.dart';
import '../secure_storage_service.dart';
import '../core/user/user_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final token = await _storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _conversations = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        print("Erreur API Conversations: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erreur loading convers: $e");
      setState(() => _isLoading = false);
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

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Erreur search: $e");
    }
  }

  void _openChat(String otherId, String otherName, {String? productId, String? productName, double? productPrice, String? productImage}) {
    // userState est un AsyncValue<User?>, donc on doit accéder à .value ou .asData?.value
    final userState = ref.read(userProvider);
    final myId = userState.value?.id.toString();

    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: Profil non chargé")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          myId: myId,
          otherId: otherId,
          otherName: otherName,
          productId: productId,
          productName: productName,
          productPrice: productPrice,
          productImage: productImage,
        ),
      ),
    ).then((_) => _fetchConversations()); // Refresh au retour
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
          subtitle: Text("Appuyez pour discuter"),
          onTap: () => _openChat(user['id'].toString(), user['name']),
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
            TextButton(
              onPressed: () {
                // Focus search
              }, 
              child: const Text("Chercher quelqu'un")
            )
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        // conv: conversation_id, other_name, other_avatar, other_id, last_message, last_time
        // + product_id, product_name, product_price, product_image (si lié à un produit)
        
        final hasProduct = conv['product_id'] != null;
        
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: conv['other_avatar'] != null ? NetworkImage(conv['other_avatar']) : null,
                child: conv['other_avatar'] == null ? Text(conv['other_name'][0].toUpperCase()) : null,
              ),
              // Badge produit si lié
              if (hasProduct)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_bag, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          title: Text(
            conv['other_name'], 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Afficher le nom du produit si lié
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
                style: TextStyle(color: conv['last_message'] != null ? Colors.black87 : Colors.blue),
              ),
            ],
          ),
          trailing: Text(
             _formatTime(conv['last_time']),
             style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: () => _openChat(
            conv['other_id'].toString(), 
            conv['other_name'],
            productId: conv['product_id']?.toString(),
            productName: conv['product_name'],
            productPrice: conv['product_price'] != null ? double.tryParse(conv['product_price'].toString()) : null,
            productImage: conv['product_image'],
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
