import 'package:oli_app/core/widgets/oli_image.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Image Carrée à gauche
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.images.isNotEmpty 
                     ? OliImage.network(product.images.first, width: 100, height: 100, fit: BoxFit.cover)
                     : Container(
                         width: 100,
                         height: 100,
                         color: isDark ? Colors.grey[800] : Colors.grey[200],
                         child: Icon(Icons.image,
                             color: isDark ? Colors.white38 : Colors.black26)),
                ),
                const SizedBox(width: 12),
                // Infos Produit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A1F2E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
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
                            style: TextStyle(
                                color: isDark ? Colors.orange : const Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 16)
                          );
                        }
                      ),
                    ],
                  ),
                ),
                // Icône Arrow
                Icon(Icons.arrow_forward_ios,
                    color: isDark ? Colors.grey[600] : Colors.grey[500], size: 14),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
