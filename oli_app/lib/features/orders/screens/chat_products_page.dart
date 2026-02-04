import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/conversations_page.dart';
import '../../chat/chat_page.dart';
import '../../../core/user/user_provider.dart';

/// Page affichant les produits pour lesquels l'utilisateur a lancé un chat
class ChatProductsPage extends ConsumerWidget {
  const ChatProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Mes discussions produits'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Erreur: $err', style: const TextStyle(color: Colors.white)),
              ),
              data: (conversations) {
                // Filtrer uniquement les conversations avec un produit
                final productConversations = conversations
                    .where((c) => c['product_id'] != null)
                    .toList();

                if (productConversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune discussion sur un produit',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos conversations produits apparaîtront ici',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productConversations.length,
                  itemBuilder: (context, index) {
                    final conv = productConversations[index];
                    final productName = conv['product_name'] ?? 'Produit';
                    final productImage = conv['product_image'];
                    final productPrice = conv['product_price']?.toString() ?? '0';
                    final sellerName = conv['other_name'] ?? 'Vendeur';
                    final lastMessage = conv['last_message'] ?? '';

                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                myId: user.id.toString(),
                                otherId: conv['other_id']?.toString() ?? '',
                                otherName: sellerName,
                                productId: conv['product_id']?.toString(),
                                productName: productName,
                                productImage: productImage,
                                productPrice: double.tryParse(productPrice),
                                otherAvatarUrl: conv['other_avatar'],
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Image du produit
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: productImage != null
                                    ? Image.network(
                                        productImage,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.shopping_bag, color: Colors.grey),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Infos produit
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$$productPrice',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            sellerName,
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (lastMessage.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMessage,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Icône chat
                              const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
