import 'package:flutter/material.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../models/product_model.dart';
import 'product_card_common.dart';

class SuperOffersSection extends StatefulWidget {
  final List<Product> products;

  const SuperOffersSection({super.key, required this.products});

  @override
  State<SuperOffersSection> createState() => _SuperOffersSectionState();
}

class _SuperOffersSectionState extends State<SuperOffersSection> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    // Repeat every 4 seconds: play shimmer then wait
    _startShimmerLoop();
  }

  void _startShimmerLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        _shimmerController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background + Content
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: const AssetImage("assets/images/fire_bg.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.9), BlendMode.darken),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                            children: [
                               const FireAnimationWidget(),
                               const SizedBox(width: 8),
                               const Text("Super Offres", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, shadows: [BoxShadow(color: Colors.black, blurRadius: 4)])),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text("Les plus populaires du moment", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, shadows: [BoxShadow(color: Colors.black, blurRadius: 4)])),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Page Super Offres bientôt disponible !'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Voir tout", style: TextStyle(color: Colors.grey[300], fontSize: 11, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, color: Colors.grey[300], size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.products.isEmpty ? 3 : (widget.products.length > 10 ? 10 : widget.products.length),
                      itemBuilder: (context, index) {
                        if (widget.products.isEmpty) return _buildPlaceholderCard();
                        final product = widget.products[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                          child: DashboardProductCard(
                            product: product,
                            priceColor: const Color(0xFFFFD700),
                            badgeText: "FLASH",
                            badgeColor: Colors.red,
                            subtitleWidget: Text("Low price", style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Glass shimmer overlay — IgnorePointer so taps pass through
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.white24,
                            Colors.white38,
                            Colors.white24,
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: [
                            0.0,
                            (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                            (_shimmerAnimation.value - 0.1).clamp(0.0, 1.0),
                            _shimmerAnimation.value.clamp(0.0, 1.0),
                            (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                            (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                            1.0,
                          ],
                          transform: const GradientRotation(0.5),
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      color: Colors.grey[900],
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class FireAnimationWidget extends StatefulWidget {
  const FireAnimationWidget({super.key});

  @override
  State<FireAnimationWidget> createState() => _FireAnimationWidgetState();
}

class _FireAnimationWidgetState extends State<FireAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 28),
          ),
        );
      },
    );
  }
}
