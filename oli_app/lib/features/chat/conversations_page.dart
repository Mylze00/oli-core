import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'chat_page.dart';
import 'socket_service.dart';
import '../../config/api_config.dart';
import '../../core/user/user_provider.dart';
import '../../core/storage/secure_storage_service.dart';

// Provider pour les conversations
final conversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(userProvider).value;
  if (user == null) return [];
  
  final storage = SecureStorageService();
  final token = await storage.getToken();
  final dio = Dio();
  
  try {
    final response = await dio.get(
      '${ApiConfig.baseUrl}/chat/conversations',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
  } catch (e) {
    debugPrint('❌ Erreur chargement conversations: $e');
  }
  return [];
});

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  int _selectedIndex = 0; // 0: Privé, 1: Market
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initSocket();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initSocket() async {
    final user = ref.read(userProvider).value;
    if (user != null) {
      final socketService = ref.read(socketServiceProvider);
      await socketService.connect(user.id.toString());
      
      socketService.onMessage((data) {
        ref.invalidate(conversationsProvider);
      });
    }
  }

  Future<void> _pickContact() async {
    // 1. Demander la permission
    if (await Permission.contacts.request().isGranted) {
      try {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          debugPrint("Contact sélectionné: ${contact.displayName}");
          
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
          if (phone != null) {
             // Ici on pourrait appeler une fonction pour chercher l'utilisateur par téléphone
             // _checkUserByPhone(phone);
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Contact sélectionné: ${contact.displayName} ($phone)")),
             );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Ce contact n'a pas de numéro de téléphone")),
             );
          }
        }
      } catch (e) {
        debugPrint("Erreur contacts: $e");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Erreur lors de la sélection: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission contacts refusée")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Discussions",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Barre de Recherche + Tabs (Header)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Rechercher un message...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Custom Tabs
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _buildTabItem(0, "Privé"),
                      _buildTabItem(1, "Market Chat"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // 2. Liste des Conversations
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/chat_bg_new.png"),
                  fit: BoxFit.cover,
                  opacity: 0.40,
                ),
              ),
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Erreur: $err")),
                data: (allConversations) {
                  // Filtrage par Type ET par Recherche
                  final filteredConversations = allConversations.where((c) {
                    final hasProduct = c['product_id'] != null;
                    final matchesType = _selectedIndex == 1 ? hasProduct : !hasProduct;
                    
                    final otherName = (c['other_name'] ?? '').toString().toLowerCase();
                    final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
                    final matchesSearch = otherName.contains(_searchQuery) || lastMsg.contains(_searchQuery);

                    return matchesType && matchesSearch;
                  }).toList();

                  if (filteredConversations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedIndex == 0 ? Icons.chat_bubble_outline : Icons.shopping_bag_outlined,
                            size: 60, 
                            color: Colors.grey[300]
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? "Aucun résultat trouvé"
                                : (_selectedIndex == 0 ? "Aucune conversation privée" : "Aucune conversation Market"),
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(conversationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: filteredConversations.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                      itemBuilder: (context, index) {
                        final conv = filteredConversations[index];
                        return ConversationTile(
                          conversation: conv,
                          currentUserId: user.id.toString(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  myId: user.id.toString(),
                                  otherId: conv['other_id']?.toString() ?? '',
                                  otherName: conv['other_name'] ?? 'Utilisateur',
                                  productId: conv['product_id']?.toString(),
                                  productName: conv['product_name'],
                                  productImage: conv['product_image'],
                                  productPrice: double.tryParse(conv['product_price']?.toString() ?? '0'),
                                  otherAvatarUrl: conv['other_avatar'],
                                ),
                              ),
                            ).then((_) {
                              ref.invalidate(conversationsProvider);
                            });
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _pickContact,
              backgroundColor: theme.primaryColor,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour une conversation individuelle
class ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  }) : super(key: key);

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final messageDate = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(messageDate);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays == 1) {
        return 'Hier';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}j';
      } else {
        return '${messageDate.day}/${messageDate.month}/${messageDate.year}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherName = conversation['other_name'] ?? 'Utilisateur';
    final lastMessage = conversation['last_message'] ?? '';
    final unreadCount = conversation['unread_count'] ?? 0;
    final productName = conversation['product_name'];
    final isOnline = conversation['is_online'] == true;
    final timestamp = conversation['last_message_time'];
    final otherAvatar = conversation['other_avatar'];

    return Material(
      color: unreadCount > 0 ? Colors.blue.withOpacity(0.05) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar avec statut en ligne
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                    child: otherAvatar == null
                        ? Text(
                            otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Indicateur de statut en ligne
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Contenu de la conversation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0 ? Colors.blue : Colors.grey[600],
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Contexte produit (si existe)
                    if (productName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.shopping_bag, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              productName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Dernier message + Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
