import 'package:flutter/material.dart';
import '../../../core/theme/oli_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/exchange_rate_provider.dart';

/// En-tête de contexte produit dans le chat — version améliorée
/// Affiche image HD, nom, prix, stock et boutons d'action
class ProductContextHeader extends ConsumerStatefulWidget {
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
  ConsumerState<ProductContextHeader> createState() => _ProductContextHeaderState();
}

class _ProductContextHeaderState extends ConsumerState<ProductContextHeader> {
  bool _isCollapsed = false;

  String? get productName => widget.productName;
  double? get productPrice => widget.productPrice;
  String? get productImage => widget.productImage;
  int? get stockQuantity => widget.stockQuantity;
  VoidCallback? get onAddToCart => widget.onAddToCart;
  VoidCallback? get onBuyNow => widget.onBuyNow;

  Widget _buildCollapseButton(Color color) {
    return IconButton(
      tooltip: _isCollapsed ? 'Afficher le produit' : 'Réduire le produit',
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
      icon: Icon(_isCollapsed ? Icons.expand_more : Icons.expand_less, color: color),
    );
  }

  /// Une seule ligne : la discussion récupère la place de la carte.
  Widget _buildCollapsed(Color surface, Color text, Color muted, Color border, String price, Color accent) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: border))),
      child: Row(
        children: [
          if (productImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                productImage!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, size: 20, color: muted),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              productName ?? 'Produit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(price, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
          _buildCollapseButton(muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (productName == null && productImage == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasStock = stockQuantity == null || stockQuantity! > 0;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? OliChatDarkColors.bar : Colors.white;
    final text = isDark ? Colors.white : Colors.black87;
    final muted = isDark ? Colors.white60 : Colors.grey.shade500;
    final border = isDark ? Colors.white12 : Colors.grey.shade200;
    
    String formattedPrice = '';
    if (productPrice != null) {
      final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
      formattedPrice = exchangeNotifier.formatProductPrice(productPrice!);
    }

    if (_isCollapsed) {
      return _buildCollapsed(surface, text, muted, border, formattedPrice, theme.primaryColor);
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
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
                          Icon(Icons.shopping_bag_outlined, size: 12, color: muted),
                          const SizedBox(width: 4),
                          Text(
                            'À propos de :',
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (hasStock ? Colors.green : Colors.red).withOpacity(0.18)
                                  : (hasStock ? Colors.green.shade50 : Colors.red.shade50),
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
                                    color: hasStock
                                        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                                        : (isDark ? Colors.redAccent : Colors.red.shade700),
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
                        style: TextStyle(
                          color: text,
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
                          formattedPrice,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildCollapseButton(muted),
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
