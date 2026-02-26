import 'package:flutter/material.dart';

/// En-tête de contexte produit dans le chat — version améliorée
/// Affiche image HD, nom, prix, stock et boutons d'action
class ProductContextHeader extends StatelessWidget {
  final String? productName;
  final double? productPrice;
  final String? productImage;
  final int? stockQuantity;
  final VoidCallback? onAddToCart;   // Ajouter au panier Chat
  final VoidCallback? onBuyNow;      // Achat direct

  const ProductContextHeader({
    super.key,
    this.productName,
    this.productPrice,
    this.productImage,
    this.stockQuantity,
    this.onAddToCart,
    this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    if (productName == null && productImage == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasStock = stockQuantity == null || stockQuantity! > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Product info row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image HD
                if (productImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      productImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported, size: 24, color: Colors.grey),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + stock badge
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            'À propos de :',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasStock ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasStock ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasStock ? 'En stock' : 'Rupture',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: hasStock ? Colors.green.shade700 : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Product name
                      Text(
                        productName ?? 'Produit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Price
                      if (productPrice != null)
                        Text(
                          '${productPrice!.toStringAsFixed(0)} FC',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          if (onAddToCart != null || onBuyNow != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  if (onAddToCart != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasStock ? onAddToCart : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 15),
                        label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.primaryColor),
                          foregroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                  if (onAddToCart != null && onBuyNow != null)
                    const SizedBox(width: 8),

                  if (onBuyNow != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasStock ? onBuyNow : null,
                        icon: const Icon(Icons.flash_on_rounded, size: 15),
                        label: const Text('Acheter', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
