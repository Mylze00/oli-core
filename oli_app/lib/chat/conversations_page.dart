import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';
import '../core/user/user_provider.dart';
import '../config/api_config.dart';
import '../core/storage/secure_storage_service.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final _storage = SecureStorageService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchConversations() async {
    try {
      final token = await _storage.getToken();
      debugPrint('🔄 Chargement des conversations...');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ ${data.length} conversations chargées');
        return data;
      } else {
        debugPrint('❌ Erreur chargement: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint("❌ Erreur fetch conversations: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final String? myId = user?.id.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discussions',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: myId == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<dynamic>>(
                  future: _fetchConversations(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(child: Text("Erreur: ${snapshot.error}"));
                    }

                    final conversations = snapshot.data ?? [];

                    if (conversations.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final int unreadCount = conv['unread_count'] ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage: conv['other_avatar'] != null
                                ? NetworkImage(conv['other_avatar'])
                                : null,
                              child: conv['other_avatar'] == null
                                ? Text(
                                    (conv['other_name'] ?? '')[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : null,
                            ),
                            title: Text(
                              conv['other_name'] ?? 'Utilisateur',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              conv['last_message'] ?? 'Aucun message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      "$unreadCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    myId: myId,
                                    otherId: conv['other_id'].toString(),
                                    otherName: conv['other_name'] ?? 'Chat',
                                    conversationId: conv['conversation_id'].toString(),
                                    productId: conv['product_id']?.toString(),
                                    productName: conv['product_name'],
                                    productPrice: conv['product_price'],
                                    productImage: conv['product_image'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
          const Text(
            "Aucune discussion pour le moment",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}