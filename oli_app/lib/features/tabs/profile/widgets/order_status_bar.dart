import 'package:flutter/material.dart';
import '../../../../pages/purchases_page.dart';

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
              _buildOrderIcon(Icons.payment, "Non Payé", textColor),
              _buildOrderIcon(Icons.inventory_2_outlined, "À expédier", textColor),
              _buildOrderIcon(Icons.local_shipping_outlined, "À recevoir", textColor),
              _buildOrderIcon(Icons.rate_review_outlined, "À noter", textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color.withOpacity(0.7)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
      ],
    );
  }
}
