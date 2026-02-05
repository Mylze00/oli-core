import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../../checkout/screens/checkout_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page Panier avec groupement par boutique
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final groupedCart = ref.watch(groupedCartProvider);
    final selectedTotal = ref.watch(selectedCartTotalProvider);
    final hasSelectedItems = ref.watch(hasSelectedItemsProvider);
    final allSelected = cartItems.every((item) => item.isSelected);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text('Panier (${cartItems.length})'),
        actions: [
          if (cartItems.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => ref.read(cartProvider.notifier).toggleAllSelection(),
              icon: Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: Colors.orangeAccent,
              ),
              label: Text(
                allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmClearCart(context, ref),
            ),
          ],
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedCart.length,
                    itemBuilder: (context, index) {
                      final sellerId = groupedCart.keys.elementAt(index);
                      final shopItems = groupedCart[sellerId]!;
                      return _buildShopSection(context, ref, sellerId, shopItems);
                    },
                  ),
                ),
                _buildSummary(context, ref, selectedTotal, hasSelectedItems),
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

  Widget _buildShopSection(BuildContext context, WidgetRef ref, String sellerId, List<CartItem> shopItems) {
    final allShopSelected = shopItems.every((item) => item.isSelected);
    final shopSubtotal = ref.read(cartProvider.notifier).getShopSubtotal(sellerId);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // En-tête boutique avec checkbox master
          InkWell(
            onTap: () => ref.read(cartProvider.notifier).toggleShopSelection(sellerId),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: allShopSelected,
                    onChanged: (_) => ref.read(cartProvider.notifier).toggleShopSelection(sellerId),
                    activeColor: Colors.orangeAccent,
                  ),
                  const Icon(Icons.store, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shopItems.first.sellerName ?? 'Boutique $sellerId',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (shopSubtotal > 0)
                    Text(
                      exchangeNotifier.formatProductPrice(shopSubtotal),
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
          // Liste des produits
          ...shopItems.map((item) => _buildCartItem(context, ref, item)),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: item.isSelected,
            onChanged: (_) => ref.read(cartProvider.notifier).toggleItemSelection(item.productId),
            activeColor: Colors.blueAccent,
          ),
          // Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              image: item.imageUrl != null
                  ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: item.imageUrl == null ? const Icon(Icons.image, color: Colors.grey, size: 30) : null,
          ),
          const SizedBox(width: 12),
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    color: item.isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  exchangeNotifier.formatProductPrice(item.price),
                  style: TextStyle(
                    color: item.isSelected ? Colors.blueAccent : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Livraison ${item.deliveryMethod}: ${exchangeNotifier.formatProductPrice(item.deliveryPrice)}",
                  style: TextStyle(color: item.isSelected ? Colors.white54 : Colors.grey.shade700, fontSize: 10),
                ),
              ],
            ),
          ),
          // Quantité
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.add_circle, color: item.isSelected ? Colors.blueAccent : Colors.grey),
                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity + 1),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${item.quantity}',
                style: TextStyle(
                  color: item.isSelected ? Colors.white : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  color: item.isSelected
                      ? (item.quantity > 1 ? Colors.orange : Colors.red)
                      : Colors.grey,
                ),
                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity - 1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, WidgetRef ref, double selectedTotal, bool hasSelectedItems) {
    final selectedItems = ref.watch(cartProvider).where((item) => item.isSelected).toList();
    final totalQuantity = selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

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
                Text(
                  '$totalQuantity article(s) sélectionné(s)',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  exchangeNotifier.formatProductPrice(selectedTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasSelectedItems
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage()))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelectedItems ? Colors.blueAccent : Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  hasSelectedItems ? 'Passer la commande' : 'Sélectionnez des articles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasSelectedItems ? Colors.white : Colors.grey.shade600,
                  ),
                ),
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
