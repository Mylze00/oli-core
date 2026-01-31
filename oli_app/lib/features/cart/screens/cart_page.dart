import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../../checkout/screens/checkout_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page Panier
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text('Panier (${cartItems.length})'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmClearCart(context, ref),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) => _buildCartItem(context, ref, cartItems[index]),
                  ),
                ),
                _buildSummary(context, ref, cartItems, total),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text('Votre panier est vide', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Ajoutez des produits pour commencer', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              image: item.imageUrl != null
                  ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: item.imageUrl == null ? const Icon(Icons.image, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (item.sellerName != null)
                  Text(item.sellerName!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 8),
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          exchangeNotifier.formatProductPrice(item.price), 
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Livraison ${item.deliveryMethod} : ${exchangeNotifier.formatProductPrice(item.deliveryPrice)}",
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
          // Quantité
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity + 1),
                visualDensity: VisualDensity.compact,
              ),
              Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.remove_circle, color: item.quantity > 1 ? Colors.orange : Colors.red),
                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity - 1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref, List<CartItem> items, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${items.fold<int>(0, (sum, item) => sum + item.quantity)} article(s)', style: const TextStyle(color: Colors.grey)),
                Consumer(
                  builder: (context, ref, _) {
                    final exchangeState = ref.watch(exchangeRateProvider);
                    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
                    return Text(
                      exchangeNotifier.formatProductPrice(total), 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Passer la commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearCart(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Vider le panier ?', style: TextStyle(color: Colors.white)),
        content: const Text('Tous les articles seront supprimés.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
