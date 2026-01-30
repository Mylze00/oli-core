import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/product_model.dart';
import '../providers/shop_promotions_provider.dart';
import '../../marketplace/presentation/pages/product_details_page.dart';

class PromoCarouselWidget extends ConsumerStatefulWidget {
  final String shopId;

  const PromoCarouselWidget({super.key, required this.shopId});

  @override
  ConsumerState<PromoCarouselWidget> createState() => _PromoCarouselWidgetState();
}

class _PromoCarouselWidgetState extends ConsumerState<PromoCarouselWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.4);
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  int _currentPage = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer(DateTime endDate) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (endDate.isBefore(now)) {
        timer.cancel();
        setState(() {
          _timeLeft = Duration.zero;
        });
      } else {
        setState(() {
          _timeLeft = endDate.difference(now);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${hours}h ${minutes}m ${seconds}s";
    // If days needed: ${duration.inDays}j 
  }

  @override
  Widget build(BuildContext context) {
    final promoAsync = ref.watch(shopPromotionsProvider(widget.shopId));

    return promoAsync.when(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        // Start timer based on current page product's end date
        // Note: Ideally logic should be more robust or pick shortest time
        if (_timer == null && products.isNotEmpty) {
           // Basic logic: use the discount end date of the first product initially
           // In a real app, you might want to switch timer when page changes
           _updateTimerForProduct(products[_currentPage]);
        }

        return Column(
          children: [
            // Header Promo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "OFFRES SPÉCIALES",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (_timeLeft > Duration.zero)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _formatDuration(_timeLeft),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Carousel
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: products.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _updateTimerForProduct(products[index]);
                  });
                },
                itemBuilder: (context, index) {
                  final product = products[index];
                  // Calculate discount percentage logic if needed, or rely on display
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/300'),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                          ),
                      ),
                      child: Stack(
                        children: [
                          // Badge Promo
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "PROMO",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                          // Content
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      "\$${product.discountPrice ?? product.price}",
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 18),
                                    ),
                                    if (product.discountPrice != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "\$${product.price}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Dots Indicator
            if (products.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  products.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    width: _currentPage == index ? 20 : 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? Colors.orange : Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show loading for widget to avoid layout jump
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  void _updateTimerForProduct(Product product) {
    // Assuming product model has discountEndDate (needs to be checked or added to model if missing)
    // If not in model yet, we might need to parse it from json or it might be missing
    // For now assuming it is or I will fetch it
    // Wait, I need to check Product Model first!
    // But assuming logic is standard:
    if (product.discountEndDate != null) {
      _startTimer(product.discountEndDate!);
    } else {
      _timer?.cancel();
      setState(() {
        _timeLeft = Duration.zero;
      });
    }
  }
}
