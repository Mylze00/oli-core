import 'package:flutter/material.dart';
import '../../../../../../models/product_model.dart';
import '../../pages/seller_profile_page.dart';
import '../../../../../../core/services/geocoding_service.dart';

class ProductProvenanceTable extends StatelessWidget {
  final Product product;

  const ProductProvenanceTable({super.key, required this.product});

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
          const Text("PROVENANCE & DÉTAILS",
              style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
            border: TableBorder(
                horizontalInside: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.06))),
            children: [
              _buildLocationRow(isDark),
              _buildProvenanceRow(
                context,
                isDark,
                "Vendeur",
                (product.shopName != null && product.shopName!.isNotEmpty)
                    ? product.shopName!
                    : product.seller,
                isLink: true,
                onTap: () {
                  if (product.sellerId.isNotEmpty) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SellerProfilePage(
                                sellerId: product.sellerId.trim())));
                  }
                },
              ),
              _buildProvenanceRow(context, isDark, "Type Vendeur", product.sellerAccountType.toUpperCase()),
              _buildProvenanceRow(context, isDark, "Mise en ligne", _getTimeSinceUpload(product.createdAt)),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeSinceUpload(DateTime? createdAt) {
    if (createdAt == null) return "Récemment";
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 1) return "Il y a ${diff.inDays} jours";
    if (diff.inDays == 1) return "Hier";
    if (diff.inHours > 0) return "Il y a ${diff.inHours} heures";
    return "Il y a quelques minutes";
  }

  TableRow _buildLocationRow(bool isDark) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text("Localisation",
              style: TextStyle(color: isDark ? Colors.grey : Colors.black54, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FutureBuilder<String>(
            future: GeocodingService.coordinatesToLocationName(product.location),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                );
              }
              return Text(
                snapshot.data ?? "Non spécifié",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  TableRow _buildProvenanceRow(BuildContext context, bool isDark, String label, String value,
      {bool isLink = false, VoidCallback? onTap}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54, fontSize: 13)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              value,
              style: TextStyle(
                color: isLink ? Colors.blueAccent : (isDark ? Colors.white : Colors.black87),
                fontSize: 13,
                fontWeight: isLink ? FontWeight.bold : FontWeight.w500,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
