import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../features/cart/providers/cart_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../../providers/exchange_rate_provider.dart';

class ProductImageCarousel extends StatefulWidget {
  final Product product;
  final Function() onShare;

  const ProductImageCarousel({
    super.key,
    required this.product,
    required this.onShare,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  int _currentImageIndex = 0;
  int _previousImageIndex = 0;

  void _onSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    final images = widget.product.images;
    if (details.primaryVelocity! < -100 && _currentImageIndex < images.length - 1) {
      setState(() {
        _previousImageIndex = _currentImageIndex;
        _currentImageIndex++;
      });
    } else if (details.primaryVelocity! > 100 && _currentImageIndex > 0) {
      setState(() {
        _previousImageIndex = _currentImageIndex;
        _currentImageIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Stack(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF1A1A1A),
            width: double.infinity,
            child: p.images.isEmpty
                ? const SizedBox(
                    height: 300,
                    child: Center(
                      child: Icon(Icons.image, size: 60, color: Colors.grey)),
                  )
                : GestureDetector(
                    onHorizontalDragEnd: _onSwipe,
                    child: Stack(
                      children: [
                        // Image précédente visible en dessous pendant le chargement
                        if (_previousImageIndex != _currentImageIndex)
                          Image.network(
                            p.images[_previousImageIndex],
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        // Image courante — se charge par-dessus
                        Image.network(
                          p.images[_currentImageIndex],
                          key: ValueKey(p.images[_currentImageIndex]),
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey, size: 60)),
                              ),
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) {
                              // Image chargée → on peut retirer l'ancienne
                              return child;
                            }
                            // Pas encore chargée → transparent (l'ancienne reste visible en dessous)
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      Positioned(
        top: 10,
        right: 16,
        child: Row(children: [
          CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.9),
              child: IconButton(
                icon:
                    const Icon(Icons.ios_share, color: Colors.black, size: 18),
                onPressed: widget.onShare,
              )),
          const SizedBox(width: 10),
          Consumer(
            builder: (context, ref, _) {
              return CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.black, size: 18),
                  onPressed: () {
                    final p = widget.product;
                    ref.read(cartProvider.notifier).addItem(
                          CartItem(
                            productId: p.id.toString(),
                            productName: p.name,
                            price: double.tryParse(p.price) ?? 0.0,
                            quantity: 1,
                            imageUrl:
                                p.images.isNotEmpty ? p.images.first : null,
                            sellerName: p.seller,
                            sellerId: p.sellerId,
                          ),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Produit ajouté au panier'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            }
          ),
        ]),
      ),
      if (p.images.length > 1)
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  p.images.length,
                  (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentImageIndex
                              ? Colors.blueAccent
                              : Colors.grey.withOpacity(0.5))))),
        ),
    ]);
  }
}
