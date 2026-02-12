import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/screens/purchases_page.dart';
import '../../../cart/screens/cart_page.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../sales/screens/my_sales_page.dart';
import '../../../user/screens/address_management_page.dart';

class OrderStatusBar extends ConsumerWidget {
  final Color cardColor;
  final Color textColor;

  const OrderStatusBar({
    super.key, 
    required this.cardColor, 
    required this.textColor
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartCount = cartItems.length;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mes Commandes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesPage())),
                child: Row(
                  children: [
                    Text("Tout voir", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOrderIcon(
                Icons.shopping_cart_outlined,
                "Panier",
                textColor,
                badgeCount: cartCount,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
              ),
              _buildOrderIcon(
                Icons.receipt_long_outlined,
                "Suivi commande",
                textColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesPage())),
              ),
              _buildOrderIcon(
                Icons.location_on_outlined,
                "Adresses",
                textColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressManagementPage())),
              ),
              _buildOrderIcon(
                Icons.sell_outlined,
                "Mes Ventes",
                textColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySalesPage())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, Color color, {VoidCallback? onTap, int badgeCount = 0}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 28, color: color.withOpacity(0.7)),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label, 
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
