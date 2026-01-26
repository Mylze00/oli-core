import 'package:flutter/material.dart';
import '../../../shop/shop_details_page.dart';
import '../../../../models/shop_model.dart';

class VerifiedShopsCarousel extends StatelessWidget {
  final List<Shop> shops;

  const VerifiedShopsCarousel({super.key, required this.shops});

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 115, // Ajusté pour cercles 80px
      margin: const EdgeInsets.only(top: 0, bottom: 2), // Marge quasi nulle
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shops.length,
        itemBuilder: (context, index) {
          final shop = shops[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailsPage(shop: shop))),
            child: Container(
              width: 100, // Augmenté pour éviter de couper
              margin: const EdgeInsets.only(right: 8), // Réduit l'espace entre les cercles
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80, // +10% de plus (Total ~80px)
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 2),
                      image: shop.logoUrl != null 
                         ? DecorationImage(image: NetworkImage(shop.logoUrl!), fit: BoxFit.cover)
                         : null,
                    ),
                    child: shop.logoUrl == null 
                        ? Center(child: Text(shop.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black)))
                        : null,
                  ),
                  const SizedBox(height: 2), // Espace texte reduit
                  Text(
                    shop.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
