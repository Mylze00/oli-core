import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../../../utils/cloudinary_helper.dart';
import '../../../user/providers/favorites_provider.dart';
import '../pages/product_details_page.dart';

class SearchProductListItem extends ConsumerWidget {
  final Product product;

  const SearchProductListItem({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.any((p) => p.id == product.id);
    // Watch currency changes
    ref.watch(exchangeRateProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Image Left
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 120,
                height: 120,
                child: product.images.isNotEmpty
                    ? Image.network(
                        CloudinaryHelper.thumbnail(product.images.first),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
              ),
            ),
            
            // Info Right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.seller,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref.read(exchangeRateProvider.notifier).formatProductPrice(double.tryParse(product.price) ?? 0.0),
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(product);
                          },
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
