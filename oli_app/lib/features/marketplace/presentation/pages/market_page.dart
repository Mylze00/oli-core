import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final marketProductsProvider = FutureProvider<List<dynamic>>((ref) async {
  const String apiUrl = 'http://127.0.0.1:3000/products';
  try {
    final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw 'Erreur serveur (${response.statusCode})';
    }
  } catch (e) {
    throw 'Serveur Oli injoignable.';
  }
});

class MarketView extends ConsumerWidget {
  const MarketView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(marketProductsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(marketProductsProvider.future),
          color: Colors.blueAccent,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(ref),
              _buildHeader(),
              productsAsync.when(
                data: (products) => _buildProductGrid(products),
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.blueAccent))),
                error: (err, _) => SliverFillRemaining(child: _buildErrorState(err.toString(), ref)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(WidgetRef ref) {
    return SliverAppBar(
      backgroundColor: Colors.black,
      floating: true, pinned: true, elevation: 0,
      title: const Text('Marché Oli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => ref.refresh(marketProductsProvider))],
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A237E), Colors.black], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Produits à Kinshasa 🇨🇩', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text('Trouvez les meilleures affaires ici.', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> products) {
    if (products.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text("Aucun produit disponible.", style: TextStyle(color: Colors.grey))));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.75),
        delegate: SliverChildBuilderDelegate((context, index) => _ProductCard(product: products[index]), childCount: products.length),
      ),
    );
  }

  Widget _buildErrorState(String error, WidgetRef ref) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off, color: Colors.redAccent, size: 40),
      const SizedBox(height: 10),
      Text(error, style: const TextStyle(color: Colors.white70)),
      TextButton(onPressed: () => ref.refresh(marketProductsProvider), child: const Text("Réessayer"))
    ]));
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(product['imageUrl'], fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (context, error, stack) => Container(color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.grey)),
            ),
        )),
        const SizedBox(height: 10),
        Text(product['name'] ?? 'Produit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1),
        Text("${product['price']} \$", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
    ]);
  }
}