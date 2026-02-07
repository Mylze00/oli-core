import 'package:flutter/material.dart';
import '../../../orders/screens/purchases_page.dart';
import '../../../orders/screens/chat_products_page.dart';
import '../../../cart/screens/cart_page.dart';
import '../../../sales/screens/my_sales_page.dart';

class OrderStatusBar extends StatelessWidget {
  final Color cardColor;
  final Color textColor;

  const OrderStatusBar({
    super.key, 
    required this.cardColor, 
    required this.textColor
  });

  @override
  Widget build(BuildContext context) {
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatProductsPage())),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()))
              ),
              _buildOrderIcon(Icons.local_shipping_outlined, "En cours", textColor),
              _buildOrderIcon(Icons.location_on_outlined, "Suivi colis", textColor),
              _buildOrderIcon(
                  Icons.sell_outlined,
                  "Mes Ventes",
                  textColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySalesPage()))
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color.withOpacity(0.7)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }
}
