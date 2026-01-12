import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// IMPORT TRÈS IMPORTANT :
import '../../../models/product_model.dart'; 
import 'product_details_page.dart';

class MarketView extends ConsumerStatefulWidget {
  const MarketView({super.key});
  @override
  ConsumerState<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends ConsumerState<MarketView> {
  @override
  Widget build(BuildContext context) {
    // Maintenant marketProductsProvider est reconnu !
    final products = ref.watch(marketProductsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Marché Public', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          childAspectRatio: 0.75, 
          crossAxisSpacing: 10, 
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => _ProductCard(product: products[index]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product; // Reconnu grâce à l'import
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.images.isEmpty
                  ? const Icon(Icons.phone_iphone, size: 50, color: Colors.blueAccent)
                  : Image.network(
                      product.images[0],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("${product.price} \$", style: const TextStyle(color: Colors.blueAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}