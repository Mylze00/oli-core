import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../models/product_model.dart';
import '../../pages/notifications_view.dart';

class MainDashboardView extends ConsumerWidget {
  const MainDashboardView({super.key});

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(marketProductsProvider);
    final authState = ref.watch(authControllerProvider);
    
    final userName = authState.userData?['name'] ?? ""; 
    final userPhone = authState.userData?['phone'] ?? "";

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // --- HEADER (LOGO & INFOS) ---
          SliverAppBar(
            expandedHeight: 200, 
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.only(left: 20, top: 50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 80, 
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.account_balance, color: Colors.blueAccent, size: 50),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userPhone,
                      style: TextStyle(
                        color: Colors.blueAccent.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(right: 15, top: 15),
                  child: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () => _navigateTo(context, const NotificationsView()),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // --- CONTENU PRINCIPAL ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 ZONE SERVICES (Titre supprimé, Arrière-plan conservé)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: _buildServiceGrid(context), // On passe le context pour la navigation
                ),

                const SizedBox(height: 35),

                // 🔹 ZONE PRODUITS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "À découvrir",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigation vers l'onglet Marché (Index 2 si on compte le bouton + comme un index)
                              // Mais ici c'est plus simple de demander au parent ou d'utiliser un message/feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Utilisez l'onglet 'Marché' en bas pour tout voir"))
                              );
                            }, 
                            child: const Text("Voir tout", style: TextStyle(color: Colors.blueAccent))
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 220,
                        child: products.isEmpty 
                          ? const Center(child: Text("Bientôt disponible", style: TextStyle(color: Colors.white24)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: products.length,
                              itemBuilder: (context, index) => _SmallProductCard(product: products[index]),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    final services = [
      {'icon': Icons.account_balance_wallet, 'label': 'Wallet', 'color': Colors.blueAccent},
      {'icon': Icons.phone_android, 'label': 'Crédit', 'color': Colors.orange},
      {'icon': Icons.bolt, 'label': 'Électricité', 'color': Colors.yellow},
      {'icon': Icons.more_horiz, 'label': 'Plus', 'color': Colors.grey},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: services.map((s) => InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Service ${s['label']} bientôt disponible"))
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: (s['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(s['label'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      )).toList(),
    );
  }
}

class _SmallProductCard extends StatelessWidget {
  final Product product;
  const _SmallProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: product.images.isEmpty
                  ? const Icon(Icons.shopping_bag_outlined, color: Colors.blueAccent, size: 40)
                  : Image.network(
                      product.images[0],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("${product.price} \$", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
