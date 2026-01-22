import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  Future<void> _initSocket() async {
    final user = ref.read(userProvider).value;
    if (user != null) {
      final socketService = ref.read(socketServiceProvider);
      await socketService.connect(user.id.toString());
      
      // Écouter les nouveaux messages pour mettre à jour la liste
      socketService.onMessage((data) {
        // Rafraîchir la liste des conversations
        ref.invalidate(conversationsProvider);
      });
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
      appBar: AppBar(
        title: const Text("Mes Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(conversationsProvider),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          // Si l'erreur est liée à l'auth, on pourrait rediriger, mais main.dart le fait déjà.
          // Ici on affiche juste l'erreur proprement.
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Impossible de charger les messages",
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  err.toString().replaceAll('Exception: ', ''),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Réessayer"),
                ),
              ],
            ),
          );
        },
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text("Aucune conversation pour le moment"));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final otherId = conv['other_id']?.toString() ?? '';
                final otherName = conv['other_name'] ?? 'Utilisateur';
                final lastMessage = conv['last_message'] ?? '';
                final unreadCount = conv['unread_count'] ?? 0;
                final productImage = conv['product_image'];
                final productName = conv['product_name'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    backgroundImage: conv['other_avatar'] != null 
                        ? NetworkImage(conv['other_avatar']) 
                        : null,
                    child: conv['other_avatar'] == null 
                        ? Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(otherName)),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (productName != null)
                        Text(
                          '📦 $productName',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  isThreeLine: productName != null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          myId: user.id.toString(),
                          otherId: otherId,
                          otherName: otherName,
                          productId: conv['product_id']?.toString(),
                          productName: productName,
                          productImage: productImage,
                          productPrice: double.tryParse(conv['product_price']?.toString() ?? '0'),
                          otherAvatarUrl: conv['other_avatar'],
                        ),
                      ),
                    ).then((_) {
                      // Rafraîchir après retour du chat
                      ref.invalidate(conversationsProvider);
                    });
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}