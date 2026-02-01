import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/seller_provider.dart';
import '../../providers/market_provider.dart';
import '../widgets/market_product_card.dart';
import 'product_details_page.dart';  // For navigation to products

class SellerProfilePage extends ConsumerStatefulWidget {
  final String sellerId;
  const SellerProfilePage({super.key, required this.sellerId});

  @override
  ConsumerState<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends ConsumerState<SellerProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerProvider.notifier).fetchSellerProfile(widget.sellerId);
      ref.read(marketProductsProvider.notifier).fetchProducts(sellerId: widget.sellerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(sellerProvider);
    final productsAsync = ref.watch(marketProductsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profil Vendeur", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: sellerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Erreur: $err\n(ID: ${widget.sellerId})", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
        data: (profile) {
          final products = productsAsync.valueOrNull ?? [];
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildProfileHeader(profile),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Produits en vente (${products.length})",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              productsAsync.when(
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Text("Erreur chargement produits: $e"))),
                data: (productsList) {
                  if (productsList.isEmpty) {
                     return const SliverToBoxAdapter(
                       child: Padding(
                         padding: EdgeInsets.all(20),
                         child: Center(child: Text("Aucun produit en vente pour le moment.", style: TextStyle(color: Colors.grey))),
                       )
                     );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => MarketProductCard(product: productsList[index]),
                        childCount: productsList.length,
                      ),
                    ),
                  );
                }
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(SellerProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: profile.avatarUrl != null 
                    ? NetworkImage(profile.avatarUrl!) 
                    : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                        ],
                        if (profile.accountType == 'entreprise' || profile.hasCertifiedShop) ...[
                           const SizedBox(width: 5),
                           Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                              child: const Text("PRO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                           ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Membre depuis ${profile.joinedAt != null ? DateFormat('MMMM yyyy').format(profile.joinedAt!) : 'Inconnu'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (profile.shopName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text("Boutique: ${profile.shopName}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Ventes", "${profile.totalSales}"),
              _buildStatItem("Note", "${profile.rating} ⭐"),
              _buildStatItem("Statut", profile.isVerified ? "Vérifié" : "Standard"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
