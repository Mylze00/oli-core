import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketCheckoutSummary extends StatelessWidget {
  final double basePrice;
  final int quantity;
  final VoidCallback onPayPressed;
  final bool isLoading;

  const TicketCheckoutSummary({
    super.key,
    required this.basePrice,
    required this.quantity,
    required this.onPayPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. CALCULS (Règle métier stricte)
    final double subtotal = basePrice * quantity;
    final double platformFee = subtotal * 0.08;
    final double totalToPay = subtotal + platformFee;

    // Formatter pour afficher les prix proprement (ex: 2,500.00 FC)
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FC',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Résumé de la commande",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Sous-total
            _buildSummaryRow(
              "Billet(s) x$quantity", 
              currencyFormatter.format(subtotal),
            ),
            const SizedBox(height: 8),
            
            // Frais de plateforme (Transparence)
            _buildSummaryRow(
              "Frais de service (8%)", 
              currencyFormatter.format(platformFee),
              isFee: true,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total à payer",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  currencyFormatter.format(totalToPay),
                  style: const TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.blueAccent
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Bouton de paiement unique
            ElevatedButton(
              onPressed: isLoading ? null : onPayPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, 
                        strokeWidth: 2
                      ),
                    )
                  : const Text(
                      "Payer maintenant",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isFee = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isFee ? Colors.grey.shade600 : Colors.black87,
            fontSize: 14,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: isFee ? Colors.grey.shade600 : Colors.black87,
            fontWeight: isFee ? FontWeight.normal : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
