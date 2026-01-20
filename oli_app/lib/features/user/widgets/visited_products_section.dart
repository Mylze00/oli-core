import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visited_product_model.dart';
import '../providers/user_activity_provider.dart';

class VisitedProductsSection extends ConsumerWidget {
  const VisitedProductsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(userActivityProvider);
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Récemment Consultés',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (activityState.visitedProducts.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    // Could navigate to a full history page
                  },
                  child: Row(
                    children: [
                      Text(
                        'Tout voir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (activityState.isLoading && activityState.visitedProducts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (activityState.visitedProducts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun produit consulté récemment',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: activityState.visitedProducts.length,
              itemBuilder: (context, index) {
                final product = activityState.visitedProducts[index];
                return _VisitedProductCard(product: product);
              },
            ),
          ),
      ],
    );
  }
}

class _VisitedProductCard extends StatelessWidget {
  final VisitedProduct product;

  const _VisitedProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to product detail page
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => ProductDetailPage(productId: product.id)
        // ));
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        height: 80,
                        width: 120,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          width: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 80,
                        width: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.shopping_bag, color: Colors.grey),
                      ),
              ),
              // Product info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E7DBA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
