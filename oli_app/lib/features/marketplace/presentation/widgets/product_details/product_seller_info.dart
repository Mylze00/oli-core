import 'package:flutter/material.dart';
import '../../../../../../models/product_model.dart';
import '../../../../../../widgets/verification_badge.dart';

class ProductSellerInfo extends StatelessWidget {
  final Product product;
  final Function() onSellerTap;
  final Function() onChatTap;

  const ProductSellerInfo({
    super.key,
    required this.product,
    required this.onSellerTap,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    // Filter out placeholder 'BOUTIQUE ENTREPRISE' and use actual shop/seller name
    final isValidShopName = p.shopName != null && 
                           p.shopName!.isNotEmpty && 
                           p.shopName!.toUpperCase() != 'BOUTIQUE ENTREPRISE';
    
    final displayName = isValidShopName ? p.shopName! : p.seller;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onSellerTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage: p.shopName != null && p.shopVerified
                        ? null // TODO : Ajouter le logo de la boutique s'il est disponible dans le modèle
                        : p.sellerAvatar != null
                            ? NetworkImage(p.sellerAvatar!)
                            : null,
                    child: (p.shopName == null && p.sellerAvatar == null)
                        ? Text(displayName.isNotEmpty ? displayName[0] : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20))
                        : null,
                  ),
                  // Badge de vérification superposé - only for certified
                  if (p.sellerHasCertifiedShop ||
                      p.sellerAccountType == 'entreprise' ||
                      p.sellerAccountType == 'certifie' ||
                      p.sellerIsVerified ||
                      p.shopVerified)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: VerificationBadge(
                        type: (p.shopVerified ||
                                p.sellerHasCertifiedShop ||
                                p.sellerAccountType == 'entreprise')
                            ? BadgeType.gold
                            : BadgeType.blue,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16)),
                      if (p.shopName != null || p.sellerHasCertifiedShop)
                        const Text('CONFIANCE GARANTIE',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),

                      // Stats vendeur
                      Row(
                        children: [
                          Text('${p.totalBuyerRatings}% positif',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('• ${p.sellerSalesCount} ventes',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Colors.black, size: 30),
                onPressed: onChatTap,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
