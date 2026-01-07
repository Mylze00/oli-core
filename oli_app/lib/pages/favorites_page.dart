import 'package:flutter/material.dart';

/// Page "Favoris et Suivis"
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data - À remplacer par API backend
  final List<FavoriteProduct> _favorites = [
    FavoriteProduct(id: '1', name: 'iPhone 15 Pro Max', price: 1400, seller: 'Apple Store', image: null),
    FavoriteProduct(id: '2', name: 'Sony WH-1000XM5', price: 350, seller: 'Sony Official', image: null),
    FavoriteProduct(id: '3', name: 'Nintendo Switch OLED', price: 320, seller: 'GameZone', image: null),
    FavoriteProduct(id: '4', name: 'iPad Pro 12.9"', price: 1100, seller: 'TechWorld', image: null),
  ];

  final List<FollowedSeller> _followedSellers = [
    FollowedSeller(id: '1', name: 'Apple Store', productsCount: 156, rating: 4.9),
    FollowedSeller(id: '2', name: 'TechWorld', productsCount: 89, rating: 4.7),
    FollowedSeller(id: '3', name: 'GameZone', productsCount: 234, rating: 4.5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Favoris et Suivis'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Produits (${_favorites.length})'),
            Tab(text: 'Vendeurs (${_followedSellers.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsGrid(),
          _buildSellersList(),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_favorites.isEmpty) {
      return _buildEmptyState(Icons.favorite_border, 'Aucun favori', 'Les produits que vous aimez apparaîtront ici');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) => _buildProductCard(_favorites[index]),
    );
  }

  Widget _buildProductCard(FavoriteProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + bouton supprimer
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: product.image != null
                      ? Image.network(product.image!, fit: BoxFit.cover)
                      : const Icon(Icons.image, color: Colors.grey, size: 40),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeFavorite(product),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite, color: Colors.red, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Détails
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(product.seller, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const SizedBox(height: 6),
                Text('\$${product.price}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellersList() {
    if (_followedSellers.isEmpty) {
      return _buildEmptyState(Icons.store_outlined, 'Aucun vendeur suivi', 'Suivez des vendeurs pour voir leurs nouveautés');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followedSellers.length,
      itemBuilder: (context, index) => _buildSellerCard(_followedSellers[index]),
    );
  }

  Widget _buildSellerCard(FollowedSeller seller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blueAccent,
            child: Text(seller.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seller.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${seller.rating}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.inventory_2_outlined, color: Colors.grey.shade600, size: 14),
                    Text(' ${seller.productsCount} produits', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _unfollowSeller(seller),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Suivi', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _removeFavorite(FavoriteProduct product) {
    setState(() => _favorites.remove(product));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} retiré des favoris'),
        action: SnackBarAction(label: 'Annuler', onPressed: () => setState(() => _favorites.add(product))),
      ),
    );
  }

  void _unfollowSeller(FollowedSeller seller) {
    setState(() => _followedSellers.remove(seller));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vous ne suivez plus ${seller.name}'),
        action: SnackBarAction(label: 'Annuler', onPressed: () => setState(() => _followedSellers.add(seller))),
      ),
    );
  }
}

class FavoriteProduct {
  final String id;
  final String name;
  final double price;
  final String seller;
  final String? image;

  FavoriteProduct({required this.id, required this.name, required this.price, required this.seller, this.image});
}

class FollowedSeller {
  final String id;
  final String name;
  final int productsCount;
  final double rating;

  FollowedSeller({required this.id, required this.name, required this.productsCount, required this.rating});
}
