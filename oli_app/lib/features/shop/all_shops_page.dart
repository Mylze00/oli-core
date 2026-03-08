import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/shop_model.dart';
import '../tabs/dashboard/providers/shops_provider.dart';
import 'shop_details_page.dart';

class AllShopsPage extends ConsumerStatefulWidget {
  const AllShopsPage({super.key});

  @override
  ConsumerState<AllShopsPage> createState() => _AllShopsPageState();
}

class _AllShopsPageState extends ConsumerState<AllShopsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(verifiedShopsProvider);

    // ── Fond : verre dépoli iOS sur l'écran entier ──────────────────────
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Couche de flou sur tout ce qui est derrière ──────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                color: Colors.black.withOpacity(0.50),
              ),
            ),
          ),

          // ── Contenu ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Toutes les Boutiques',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Barre de recherche ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.22)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une boutique...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.45), fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Colors.white.withOpacity(0.55), size: 20),
                            suffixIcon: _query.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => setState(() {
                                      _query = '';
                                      _searchCtrl.clear();
                                    }),
                                    child: Icon(Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.55), size: 18),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Grille ────────────────────────────────────────────
                Expanded(
                  child: shopsAsync.when(
                    data: (shops) {
                      final filtered = _query.isEmpty
                          ? shops
                          : shops
                              .where((s) =>
                                  s.name.toLowerCase().contains(_query))
                              .toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded,
                                  size: 52,
                                  color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune boutique trouvée',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 22,
                          childAspectRatio: 0.80,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildCircleItem(context, filtered[index]),
                      );
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    error: (e, _) => Center(
                      child: Text('Erreur: $e',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleItem(BuildContext context, Shop shop) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopDetailsPage(shop: shop)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cercle logo ─────────────────────────────────────────────
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1.5,
                  ),
                ),
                child: shop.logoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          shop.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(shop),
                        ),
                      )
                    : _initial(shop),
              ),
            ),
          ),

          const SizedBox(height: 9),

          // ── Nom ──────────────────────────────────────────────────────
          Text(
            shop.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(Shop shop) => Center(
        child: Text(
          shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
        ),
      );
}
