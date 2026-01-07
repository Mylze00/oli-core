import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'market_provider.dart';
import 'pages/cart_page.dart';
import 'providers/cart_provider.dart';

class MarketView extends ConsumerWidget {
  const MarketView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(marketProductsProvider);
    final cartItemCount = ref.watch(cartItemCountProvider);

    // --- COULEURS OLI ---
    const primaryBlue = Color(0xFF1A237E); 
    const scaffoldBg = Color(0xFFF5F5F5); // Gris très clair pour faire ressortir les cartes

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(marketProductsProvider.future),
          color: primaryBlue,
          child: CustomScrollView(
            slivers: [
              // 1. Barre de recherche et Tabs (Bleu Oli)
              _buildModernAppBar(context, primaryBlue, cartItemCount),

              // 2. Actions rapides
              _buildQuickActions(primaryBlue),

              // 3. Titre de section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    children: const [
                      Text('Top Deals à Kinshasa', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              // 4. Grille de produits
              productsAsync.when(
                data: (products) => _buildProductGrid(products),
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: primaryBlue)),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: Center(child: Text("Erreur : $err")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BARRE DE RECHERCHE CONVIVIALE ---
  Widget _buildModernAppBar(BuildContext context, Color color, int cartCount) {
    return SliverAppBar(
      backgroundColor: color,
      floating: true,
      pinned: true,
      expandedHeight: 110,
      elevation: 0,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage())),
            ),
            if (cartCount > 0)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Text("Produits", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Vendeurs", style: TextStyle(color: Colors.white70)),
                Text("Services", style: TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Rechercher sur Oli...",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Color color) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        child: Row(
          children: [
            _actionItem(Icons.grid_view_rounded, "Catégories", color),
            _actionItem(Icons.local_shipping_outlined, "Livraison", color),
            _actionItem(Icons.verified_user_outlined, "Garantie", color),
            _actionItem(Icons.Location_on_outlined, "Proximité", color),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(IconData icon, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> products) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.70, // un peu plus haut pour le bouton
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ProductCard(product: products[index]),
          childCount: products.length,
        ),
      ),
    );
  }
}

// --- CARTE PRODUIT AVEC BOUTON PANIER ---
class _ProductCard extends ConsumerWidget {
  final dynamic product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                product['imageUrl'] ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Produit Oli',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "\$${price.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E)),
                    ),
                    InkWell(
                      onTap: () {
                        ref.read(cartProvider.notifier).addItem(CartItem(
                          productId: product['id'].toString(),
                          productName: product['name'] ?? 'Inconnu',
                          price: price,
                          imageUrl: product['imageUrl'],
                        ));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product['name']} ajouté au panier'),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(label: 'Voir', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()))),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF1A237E), shape: BoxShape.circle),
                        child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                  child: Text("Kinshasa", style: TextStyle(color: Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}