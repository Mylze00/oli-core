import 'package:flutter/material.dart';

class ProductContextHeader extends StatelessWidget {
  final String? productName;
  final double? productPrice;
  final String? productImage;

  const ProductContextHeader({
    super.key,
    this.productName,
    this.productPrice,
    this.productImage,
  });

  @override
  Widget build(BuildContext context) {
    if (productName == null && productImage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (productImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                productImage!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[100],
                  child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text(
                      "À propos de :",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  productName ?? 'Produit',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (productPrice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${productPrice!.toStringAsFixed(0)} FC',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
