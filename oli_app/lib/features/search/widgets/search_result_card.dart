import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';
import '../../marketplace/presentation/pages/product_details_page.dart';

/// Widget de carte produit pour les résultats de recherche (disposition horizontale)
class SearchResultCard extends ConsumerWidget {
  final Product product;

  const SearchResultCard({
    super.key,
    required this.product,
  });

  /// Calcule la date de livraison prévue à partir du délai
  String _calculateDeliveryDate(String deliveryTime) {
    // Extraire le nombre de jours depuis deliveryTime (ex: "2 jours", "10-15 jours")
    final match = RegExp(r'(\d+)').firstMatch(deliveryTime);
    if (match == null) return deliveryTime;

    final days = int.tryParse(match.group(1) ?? '0') ?? 0;
    final deliveryDate = DateTime.now().add(Duration(days: days));

    // Formater la date (ex: "19 Fév")
    final formatter = DateFormat('dd MMM', 'fr_FR');
    return 'Livraison: ${formatter.format(deliveryDate)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeState = ref.watch(exchangeRateProvider);
    final exchangeNotifier = ref.read(exchangeRateProvider.notifier);

    // Calculer le prix
    final priceUsd = double.tryParse(product.price) ?? 0.0;
    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0;
    
    final displayPrice = exchangeState.selectedCurrency == Currency.USD
        ? priceUsd
        : exchangeNotifier.convertAmount(priceUsd, from: Currency.USD);
    final formattedPrice = exchangeNotifier.formatAmount(displayPrice, currency: exchangeState.selectedCurrency);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(product: product),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (gauche)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: product.images.isEmpty
                    ? Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      )
                    : Image.network(
                        product.images[0],
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                        ),
                      ),
              ),
            ),

            // Informations (droite)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nom du produit et vendeur
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Nom du vendeur
                        Row(
                          children: [
                            const Icon(Icons.store, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                product.seller,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Prix
                    Row(
                      children: [
                        if (hasDiscount) ...[
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            exchangeNotifier.formatAmount(
                              exchangeState.selectedCurrency == Currency.USD
                                  ? product.discountPrice!
                                  : exchangeNotifier.convertAmount(product.discountPrice!, from: Currency.USD),
                              currency: exchangeState.selectedCurrency,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9500),
                            ),
                          ),
                        ] else
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E7DBA),
                            ),
                          ),
                      ],
                    ),

                    // Livraison et vendeur
                    Row(
                      children: [
                        // Date de livraison prévue
                        if (product.deliveryTime.isNotEmpty) ...[
                          const Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _calculateDeliveryDate(product.deliveryTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        
                        const SizedBox(width: 12),
                        
                        // Badge boutique vérifiée
                        if (product.shopVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green, width: 0.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.green),
                                SizedBox(width: 2),
                                Text(
                                  'Vérifié',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Badge promo (coin supérieur droit)
            if (hasDiscount)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PROMO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
