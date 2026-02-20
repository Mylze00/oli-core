import 'package:flutter/material.dart';
import '../models/video_sale_model.dart';

/// Bottom sheet affichant les détails du produit lié à la vidéo
class ProductBottomSheet extends StatelessWidget {
  final VideoSale video;

  const ProductBottomSheet({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image produit + infos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image produit
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[850],
                        child: video.productImages != null && video.productImages!.isNotEmpty
                            ? Image.network(
                                video.productImages!.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white30,
                                  size: 40,
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white30,
                                size: 40,
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Infos produit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.productName ?? 'Produit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (video.productPrice != null)
                            Text(
                              '\$${video.productPrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFFFF6D00),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Vendeur
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: video.sellerAvatar != null
                                    ? NetworkImage(video.sellerAvatar!)
                                    : null,
                                child: video.sellerAvatar == null
                                    ? const Icon(Icons.person, size: 14, color: Colors.white54)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                video.sellerName,
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                              if (video.sellerCertified) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified, color: Colors.blue[400], size: 14),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Boutons d'action
                Row(
                  children: [
                    // Voir le produit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Naviguer vers la page produit
                          // Navigator.push(context, MaterialPageRoute(
                          //   builder: (_) => ProductDetailsPage(productId: video.productId!),
                          // ));
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Voir le produit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Ajouter au panier
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Ajouter au panier via cartProvider
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produit ajouté au panier !'),
                              backgroundColor: Color(0xFF00C853),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Ajouter au panier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6D00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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
    );
  }
}
