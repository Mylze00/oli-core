import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../shop/shop_details_page.dart';
import '../../../shop/all_shops_page.dart';
import '../../../../models/shop_model.dart';

class VerifiedShopsCarousel extends ConsumerWidget {
  final List<Shop> shops;

  const VerifiedShopsCarousel({super.key, required this.shops});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shops.isEmpty) return const SizedBox.shrink();
    final isDark = ref.watch(themeProvider);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        // Header avec titre et flèche
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Row(
                children: [
                  Icon(Icons.storefront, color: textColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Boutiques Vérifiées",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllShopsPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Voir tout",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: textColor, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste horizontale des boutiques
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailsPage(shop: shop))),
                child: Container(
                  width: 85, // Réduit de 20% (100 -> 85)
                  margin: const EdgeInsets.only(right: 6), // Espacement réduit de 20%
                  child: Column(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                          image: shop.logoUrl != null 
                             ? DecorationImage(image: NetworkImage(shop.logoUrl!), fit: BoxFit.cover)
                             : null,
                        ),
                        child: shop.logoUrl == null 
                            ? Center(child: Text(shop.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)))
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop.name,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
