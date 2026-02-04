import 'package:flutter/material.dart';
import '../../../models/shop_model.dart';

/// Section infos vendeur enrichie style Alibaba
class EnrichedSellerInfo extends StatelessWidget {
  final Shop shop;
  final VoidCallback? onInfoPressed;

  const EnrichedSellerInfo({
    super.key,
    required this.shop,
    this.onInfoPressed,
  });

  int get _yearsActive {
    // Utiliser totalSales pour estimer les années d'activité (approximation)
    int years = 1;
    if (shop.totalSales != null && shop.totalSales! > 100) {
      years = (shop.totalSales! ~/ 50).clamp(1, 10);
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding supprimé pour intégration flexible
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom boutique
          Row(
            children: [
              Expanded(
                child: Text(
                  shop.name,
                  style: const TextStyle(
                    fontSize: 24, // Plus grand comme sur l'image
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Blanc car probablement sur fond sombre/image
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Badge ENTREPRISE (Mention vérifier)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A500), // Jaune doré/moutarde
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  "ENTREPRISE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Stats ligne: Note · Années · En ligne · Localisation (RDC)
          Row(
            children: [
              // Note
              Text(
                "${shop.rating.toStringAsFixed(1)}/5",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white, // Texte en blanc pour ressortir si fond sombre ou transparent
                ),
              ),
              _buildDot(),
              // Années
              Text(
                "$_yearsActive ans",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              _buildDot(),
               // En ligne
              /* const Text(
                "En ligne",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.greenAccent, // Vert pour "En ligne"
                ),
              ),
              _buildDot(), */
              // Localisation avec drapeau RDC
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  "🇨🇩", // Drapeau RDC
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "RDC",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        "·",
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
