import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../features/cart/providers/cart_provider.dart';
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
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images;

    return Stack(
      children: [
        // ── Carrousel principal ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 340,
              child: Container(
                color: const Color(0xFF1A1A1A),
                width: double.infinity,
                child: images.isEmpty
                    ? const Center(
                        child: Icon(Icons.image, size: 60, color: Colors.grey),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() => _currentImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _openFullscreen(context, images, index),
                            child: _CarouselImageTile(
                              url: images[index],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),

        // ── Boutons Partage + Panier ──────────────────────────────────────
        Positioned(
          top: 10,
          right: 24,
          child: Row(
            children: [
              _ActionCircle(
                icon: Icons.ios_share,
                onTap: widget.onShare,
              ),
              const SizedBox(width: 10),
              Consumer(
                builder: (context, ref, _) {
                  return _ActionCircle(
                    icon: Icons.shopping_cart_outlined,
                    onTap: () {
                      ref.read(cartProvider.notifier).addItem(
                            CartItem(
                              productId: p.id.toString(),
                              productName: p.name,
                              price: double.tryParse(p.price) ?? 0.0,
                              quantity: 1,
                              imageUrl: images.isNotEmpty ? images.first : null,
                              sellerName: p.seller,
                              sellerId: p.sellerId,
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Produit ajouté au panier'),
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
                  );
                },
              ),
            ],
          ),
        ),

        // ── Indicateur de pages (points) ─────────────────────────────────
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: i == _currentImageIndex ? 18 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _currentImageIndex
                        ? Colors.blueAccent
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),

        // ── Compteur "1 / N" ─────────────────────────────────────────────
        if (images.length > 1)
          Positioned(
            top: 12,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Ouvre un viewer plein écran au tap sur une image
  void _openFullscreen(BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ── Tuile image avec placeholder shimmer opaque ────────────────────────────
class _CarouselImageTile extends StatefulWidget {
  final String url;
  const _CarouselImageTile({required this.url});

  @override
  State<_CarouselImageTile> createState() => _CarouselImageTileState();
}

class _CarouselImageTileState extends State<_CarouselImageTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      key: ValueKey(widget.url),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      /// Placeholder opaque pendant le chargement → aucune image précédente visible
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          // Image prête → on l'affiche avec un fade-in
          return AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        }
        // Pendant le téléchargement → shimmer opaque gris-foncé
        return AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) => Container(
            height: 300,
            color: Color.lerp(
              const Color(0xFF1A1A1A),
              const Color(0xFF2E2E2E),
              _shimmer.value,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox(
        height: 300,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
        ),
      ),
    );
  }
}

// ── Widget bouton circulaire ────────────────────────────────────────────────
class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.9),
      child: IconButton(
        icon: Icon(icon, color: Colors.black, size: 18),
        onPressed: onTap,
      ),
    );
  }
}

// ── Viewer plein écran (swipe + zoom) ──────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _ctrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 80,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
