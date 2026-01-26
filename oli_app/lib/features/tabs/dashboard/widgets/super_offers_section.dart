import 'package:flutter/material.dart';
import '../../../marketplace/presentation/pages/product_details_page.dart';
import '../../../../models/product_model.dart';
import 'product_card_common.dart';

class SuperOffersSection extends StatelessWidget {
  final List<Product> products;

  const SuperOffersSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black, // Fallback
        image: DecorationImage(
          image: const AssetImage("assets/images/fire_bg.png"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
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
              Icon(Icons.arrow_forward, color: Colors.grey[400], size: 18),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: products.isEmpty ? 3 : products.length,
              itemBuilder: (context, index) {
                if (products.isEmpty) return _buildPlaceholderCard();
                final product = products[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product))),
                  child: DashboardProductCard(
                    product: product,
                    priceColor: Colors.redAccent,
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
