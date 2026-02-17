import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../../checkout/screens/checkout_page.dart';
import '../../../providers/exchange_rate_provider.dart';

/// Page Panier Premium — Dark Mode avec groupement par vendeur
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final groupedCart = ref.watch(groupedCartProvider);
    final selectedTotal = ref.watch(selectedCartTotalProvider);
    final hasSelectedItems = ref.watch(hasSelectedItemsProvider);
    final allSelected = cartItems.isNotEmpty && cartItems.every((item) => item.isSelected);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const Text(
              'Mon Panier',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(width: 10),
            if (cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cartItems.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          if (cartItems.isNotEmpty) ...[
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).toggleAllSelection(),
              child: Text(
                allSelected ? 'Désélectionner' : 'Tout',
                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
              onPressed: () => _confirmClearCart(context, ref),
            ),
          ],
        ],
      ),
      body: cartItems.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: groupedCart.length,
                    itemBuilder: (context, index) {
                      final sellerId = groupedCart.keys.elementAt(index);
                      final shopItems = groupedCart[sellerId]!;
                      return _buildShopSection(context, ref, sellerId, shopItems);
                    },
                  ),
                ),
                _buildSummaryBar(context, ref, selectedTotal, hasSelectedItems),
              ],
            ),
    );
  }

  // =============================================
  // EMPTY CART
  // =============================================
  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF4A4A6A)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Votre panier est vide',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Explorez le marché et trouvez\ndes articles qui vous plaisent',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.storefront_rounded, size: 20),
            label: const Text('Explorer le Marché'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // SHOP SECTION
  // =============================================
  Widget _buildShopSection(BuildContext context, WidgetRef ref, String sellerId, List<CartItem> shopItems) {
    final allShopSelected = shopItems.every((item) => item.isSelected);
    final shopSubtotal = ref.read(cartProvider.notifier).getShopSubtotal(sellerId);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);
    final isCertified = shopItems.any((item) => item.isCertified);
    final deliveryChoice = ref.read(cartProvider.notifier).getSellerDeliveryChoice(sellerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allShopSelected ? const Color(0xFFF59E0B).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          // --------- Shop Header ---------
          InkWell(
            onTap: () => ref.read(cartProvider.notifier).toggleShopSelection(sellerId),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF16213E),
                    const Color(0xFF1A1A2E).withOpacity(0.5),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: allShopSelected,
                      onChanged: (_) => ref.read(cartProvider.notifier).toggleShopSelection(sellerId),
                      activeColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: Color(0xFF4A4A6A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store_rounded, color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            shopItems.first.sellerName ?? 'Boutique',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCertified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.blue, size: 14),
                                SizedBox(width: 3),
                                Text('Certifié', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (shopSubtotal > 0)
                    Text(
                      exchangeNotifier.formatProductPrice(shopSubtotal),
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),

          // --------- Per-seller delivery choice ---------
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A4A), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, color: Color(0xFF6B7280), size: 16),
                  const SizedBox(width: 8),
                  const Text('Livraison:', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        _buildDeliveryChip(
                          ref: ref,
                          sellerId: sellerId,
                          choice: 'pick_go',
                          label: 'Pick & Go',
                          icon: Icons.store_rounded,
                          color: Colors.green,
                          isSelected: deliveryChoice == 'pick_go',
                          isFree: true,
                        ),
                        const SizedBox(width: 8),
                        _buildDeliveryChip(
                          ref: ref,
                          sellerId: sellerId,
                          choice: 'paid_delivery',
                          label: 'Livraison',
                          icon: Icons.delivery_dining_rounded,
                          color: Colors.blue,
                          isSelected: deliveryChoice == 'paid_delivery',
                          isFree: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // --------- Product items ---------
          ...shopItems.map((item) => _buildCartItem(context, ref, item)),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // =============================================
  // DELIVERY CHIP
  // =============================================
  Widget _buildDeliveryChip({
    required WidgetRef ref,
    required String sellerId,
    required String choice,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isFree,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(cartProvider.notifier).setSellerDeliveryChoice(sellerId, choice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : const Color(0xFF2A2A4A),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : const Color(0xFF6B7280), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isFree ? '$label (Gratuit)' : label,
                  style: TextStyle(
                    color: isSelected ? color : const Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  // CART ITEM — Premium card
  // =============================================
  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.red.shade900.withOpacity(0.3)],
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.red, size: 28),
            SizedBox(height: 4),
            Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) => ref.read(cartProvider.notifier).removeItem(item.productId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFF2A2A4A).withOpacity(0.4), width: 0.5)),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: item.isSelected,
                onChanged: (_) => ref.read(cartProvider.notifier).toggleItemSelection(item.productId),
                activeColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: Color(0xFF4A4A6A)),
              ),
            ),
            const SizedBox(width: 10),

            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                image: item.imageUrl != null
                    ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: const Color(0xFF2A2A4A), width: 0.5),
              ),
              child: item.imageUrl == null
                  ? const Icon(Icons.image_rounded, color: Color(0xFF4A4A6A), size: 32)
                  : null,
            ),
            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      color: item.isSelected ? Colors.white : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exchangeNotifier.formatProductPrice(item.price),
                    style: TextStyle(
                      color: item.isSelected ? const Color(0xFFF59E0B) : const Color(0xFF4A4A6A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item.deliveryMethod == 'Pick & Go' ? Icons.store_rounded : Icons.local_shipping_rounded,
                        size: 12,
                        color: item.deliveryMethod == 'Pick & Go' ? Colors.green.shade600 : Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.deliveryMethod} · ${item.deliveryPrice == 0 ? "Gratuit" : exchangeNotifier.formatProductPrice(item.deliveryPrice)}',
                        style: TextStyle(
                          color: item.isSelected ? const Color(0xFF6B7280) : const Color(0xFF3A3A4A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quantity stepper
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2A4A), width: 0.5),
              ),
              child: Column(
                children: [
                  _buildStepperBtn(
                    icon: Icons.add_rounded,
                    color: item.isSelected ? const Color(0xFF3B82F6) : const Color(0xFF4A4A6A),
                    onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity + 1),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        color: item.isSelected ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStepperBtn(
                    icon: item.quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
                    color: item.isSelected
                        ? (item.quantity > 1 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                        : const Color(0xFF4A4A6A),
                    onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity - 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // =============================================
  // SUMMARY BAR — Glass-morphism
  // =============================================
  Widget _buildSummaryBar(BuildContext context, WidgetRef ref, double selectedTotal, bool hasSelectedItems) {
    final selectedItems = ref.watch(cartProvider).where((item) => item.isSelected).toList();
    final totalQuantity = selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalDelivery = selectedItems.fold<double>(0, (sum, item) => sum + item.deliveryPrice);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(top: BorderSide(color: Color(0xFF2A2A4A), width: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Details row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalQuantity article${totalQuantity > 1 ? 's' : ''}',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                        if (totalDelivery > 0)
                          Text(
                            'Livraison: ${exchangeNotifier.formatProductPrice(totalDelivery)}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                        ),
                        Text(
                          exchangeNotifier.formatProductPrice(selectedTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Checkout button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: hasSelectedItems
                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutPage()))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: const Color(0xFF2A2A4A),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: hasSelectedItems
                            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)])
                            : null,
                        color: hasSelectedItems ? null : const Color(0xFF2A2A4A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasSelectedItems ? Icons.shopping_bag_rounded : Icons.touch_app_rounded,
                              color: hasSelectedItems ? Colors.white : const Color(0xFF6B7280),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              hasSelectedItems ? 'Commander maintenant' : 'Sélectionnez des articles',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasSelectedItems ? Colors.white : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  // CLEAR CART DIALOG
  // =============================================
  void _confirmClearCart(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vider le panier ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Tous les articles seront supprimés de votre panier.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
