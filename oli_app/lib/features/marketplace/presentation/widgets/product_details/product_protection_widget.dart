import 'package:flutter/material.dart';

class ProductProtectionWidget extends StatelessWidget {
  const ProductProtectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Protection des commandes OLI",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white54 : Colors.black45, size: 16),
            ],
          ),
          const SizedBox(height: 16),

          // Paiements sécurisés
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Paiements sécurisés",
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPaymentLogo(
                            'assets/images/operators/orange_money.png'),
                        _buildPaymentLogo('assets/images/operators/mpesa.png'),
                        _buildPaymentLogo(
                            'assets/images/operators/airtel_money.png'),
                        _buildPaymentLogo(
                            'assets/images/operators/afrimoney.png'),
                        _buildPaymentLogo('assets/images/operators/visa.png'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Livraison
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Text("Livraison via OLI Logistics",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),

          // Remboursement
          Row(
            children: [
              const Icon(Icons.currency_exchange,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Text("Protection de remboursement",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),

          // Footer
          Text(
            "Seules les commandes passées et payées via OLI sont protégées gratuitement par OLI Assurance",
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLogo(String path) {
    return Container(
      width: 42,
      height: 27,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.all(2),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.error, size: 10, color: Colors.red),
      ),
    );
  }
}
