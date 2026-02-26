import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/providers/cart_provider.dart';
import '../../checkout/screens/checkout_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Panier local par conversation (clé = conversationId ou otherId)
/// StateProvider<List<CartItem>> stocké par conversationId
final chatCartProvider =
    StateNotifierProvider.family<ChatCartNotifier, List<CartItem>, String>(
  (ref, conversationId) => ChatCartNotifier(),
);

class ChatCartNotifier extends StateNotifier<List<CartItem>> {
  ChatCartNotifier() : super([]);

  void addProduct(CartItem item) {
    final idx = state.indexWhere((e) => e.productId == item.productId);
    if (idx >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(quantity: state[i].quantity + 1)
          else state[i]
      ];
    } else {
      state = [...state, item];
    }
  }

  void removeProduct(String productId) {
    state = state.where((e) => e.productId != productId).toList();
  }

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) {
      removeProduct(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.productId == productId) item.copyWith(quantity: qty)
        else item
    ];
  }

  void clear() => state = [];

  double get total => state.fold(0, (s, i) => s + i.price * i.quantity);
}

/// Widget panier affiché dans ChatPage quand des produits sont ajoutés
class ChatCartSummary extends ConsumerWidget {
  final String conversationId;

  const ChatCartSummary({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(chatCartProvider(conversationId));
    if (items.isEmpty) return const SizedBox.shrink();

    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final total = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Panier Chat (${items.length} article${items.length > 1 ? 's' : ''})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Items ───────────────────────────────────────────────────────
            ...items.map((item) => _CartItemRow(
              item: item,
              conversationId: conversationId,
              exchangeNotifier: exchangeNotifier,
            )),

            const Divider(height: 1, indent: 14, endIndent: 14),

            // ── Total + CTA ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(
                          exchangeNotifier.formatProductPrice(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _onBuyNow(context, ref, items),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Acheter maintenant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBuyNow(BuildContext context, WidgetRef ref, List<CartItem> items) {
    if (items.isEmpty) return;

    // Si un seul produit → achat direct via directPurchaseItem
    // Si plusieurs → les injecter dans le cartProvider global puis aller au checkout
    if (items.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutPage(directPurchaseItem: items.first),
        ),
      );
    } else {
      final cartNotifier = ref.read(cartProvider.notifier);
      for (final item in items) {
        cartNotifier.addItem(item);
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckoutPage()),
      );
    }
  }
}

class _CartItemRow extends ConsumerWidget {
  final CartItem item;
  final String conversationId;
  final dynamic exchangeNotifier;

  const _CartItemRow({
    required this.item,
    required this.conversationId,
    required this.exchangeNotifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatCartProvider(conversationId).notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Image
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.image_not_supported, size: 18, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.grey),
            ),

          const SizedBox(width: 10),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  exchangeNotifier.formatProductPrice(item.price),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () => notifier.updateQuantity(item.productId, item.quantity - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => notifier.updateQuantity(item.productId, item.quantity + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}
