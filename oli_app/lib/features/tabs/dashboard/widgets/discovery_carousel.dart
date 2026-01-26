import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../models/product_model.dart';
import '../../../../providers/exchange_rate_provider.dart';

class DiscoveryCarousel extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onTap;

  const DiscoveryCarousel({super.key, required this.products, required this.onTap});

  @override
  State<DiscoveryCarousel> createState() => _DiscoveryCarouselState();
}

class _DiscoveryCarouselState extends State<DiscoveryCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.products.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox();
    final product = widget.products[_currentIndex];

    return GestureDetector(
      onTap: () => widget.onTap(product),
      child: Container(
        height: 120, // Taille réduite pour mobile
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Container(
            key: ValueKey<String>(product.id), // Clé unique pour l'animation
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Image Carrée à gauche
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.images.isNotEmpty 
                     ? Image.network(product.images.first, width: 100, height: 100, fit: BoxFit.cover)
                     : Container(width: 100, height: 100, color: Colors.grey[800], child: const Icon(Icons.image)),
                ),
                const SizedBox(width: 12),
                // Infos Produit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("DÉCOUVERTE", style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Consumer(
                        builder: (context, ref, _) {
                          final exchangeNotifier = ref.read(exchangeRateProvider.notifier); // Just read notifier since we are rebuild via AnimatedSwitcher on parent state? No, we need watch if rate changes.
                          // But here we are inside a widget that rebuilds every 3 seconds anyway.
                          // Properly we should watch.
                          ref.watch(exchangeRateProvider);
                          final priceUsd = double.tryParse(product.price) ?? 0.0;
                          return Text(
                            exchangeNotifier.formatProductPrice(priceUsd), 
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)
                          );
                        }
                      ),
                    ],
                  ),
                ),
                // Icône Arrow
                Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
