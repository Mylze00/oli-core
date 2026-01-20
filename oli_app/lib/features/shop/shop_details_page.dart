import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import 'providers/shop_products_provider.dart';
import '../tabs/market/widgets/market_product_card.dart';
import '../tabs/market/product_details_page.dart';

class ShopDetailsPage extends ConsumerWidget {
  final Shop shop;

  const ShopDetailsPage({super.key, required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(shopProductsProvider(shop.id));

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. BANNIÈRE ET HEADER
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Bannière
                  shop.bannerUrl != null
                      ? Image.network(shop.bannerUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey[850]),
                  // Dégradé sombre
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black12, Colors.black87],
                      ),
                    ),
                  ),
                  // Logo et Infos
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: ClipOval(
                            child: shop.logoUrl != null
                                ? Image.network(shop.logoUrl!, fit: BoxFit.cover)
                                : const Icon(Icons.store, size: 30),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                shop.name,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (shop.isVerified)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("VÉRIFIÉ", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. DESCRIPTION
          if (shop.description != null && shop.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  shop.description!,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text("Produits de la boutique", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          // 3. GRILLE PRODUITS
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text("Aucun produit disponible", style: TextStyle(color: Colors.grey))),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                     crossAxisCount: 2,
                     childAspectRatio: 0.75,
                     crossAxisSpacing: 10,
                     mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: products[index]))),
                        child: MarketProductCard(product: products[index]),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Erreur: $err", style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
