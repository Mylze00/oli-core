import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/oli_surface.dart';
import '../models/shop_model.dart';
import '../providers/shop_provider.dart';
import '../../../models/shop_model.dart' as details;
import '../shop_details_page.dart';
import 'create_shop_screen.dart';

/// Mes boutiques : liste, ouverture d'une boutique et création.
class MyShopsScreen extends ConsumerWidget {
  const MyShopsScreen({super.key});

  void _create(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateShopScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = OliSurface.of(context);
    final myShopsAsync = ref.watch(myShopsProvider);

    return Scaffold(
      backgroundColor: surface.background,
      appBar: surface.appBar('Mes boutiques', actions: [
        IconButton(
          icon: Icon(Icons.add_rounded, color: surface.text),
          tooltip: 'Créer une boutique',
          onPressed: () => _create(context),
        ),
      ]),
      body: myShopsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(strokeWidth: 2, color: surface.accent)),
        error: (err, _) => OliEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Impossible de charger vos boutiques',
          subtitle: '$err',
          actionLabel: 'Réessayer',
          onAction: () => ref.invalidate(myShopsProvider),
        ),
        data: (shops) {
          if (shops.isEmpty) {
            return OliEmptyState(
              icon: Icons.storefront_outlined,
              title: "Vous n'avez pas encore de boutique",
              subtitle: 'Créez-la pour vendre sous votre propre enseigne',
              actionLabel: 'Créer ma boutique',
              onAction: () => _create(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ShopTile(shop: shops[index]),
          );
        },
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final Shop shop;
  const _ShopTile({required this.shop});

  /// La page boutique utilise son propre modèle : conversion des champs communs.
  details.Shop _toDetails(Shop s) => details.Shop(
        id: s.id.toString(),
        name: s.name,
        description: s.description,
        logoUrl: s.logoUrl,
        bannerUrl: s.bannerUrl,
        ownerId: s.ownerId.toString(),
        ownerName: s.ownerName,
        ownerAvatar: s.ownerAvatar,
        isVerified: s.isVerified,
        category: s.category,
        location: s.location,
        rating: s.rating,
        totalSales: s.totalSales,
      );

  @override
  Widget build(BuildContext context) {
    final surface = OliSurface.of(context);
    final logo = shop.logoUrl;
    return OliCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailsPage(shop: _toDetails(shop)))),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: surface.border)),
            clipBehavior: Clip.antiAlias,
            child: logo != null && logo.isNotEmpty
                ? Image.network(logo, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, color: surface.accent))
                : Icon(Icons.storefront_rounded, color: surface.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: surface.text, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(shop.category, style: TextStyle(color: surface.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: surface.textSecondary),
        ],
      ),
    );
  }
}
