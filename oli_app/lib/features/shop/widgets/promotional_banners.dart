import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/product_model.dart';

/// Bannières promotionnelles intercalées
class PromotionalBanners extends StatelessWidget {
  final List<Product> products;
  final Function(String category) onCategorySelected;

  const PromotionalBanners({
    super.key,
    required this.products,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    // Si pas de produits, on n'affiche rien ou des placeholders
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // 1. Bannière Turquoise "Réductions"
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0097A7), // Cyan foncé/Turquoise
            borderRadius: BorderRadius.circular(0), // Bord à bord ou rectangle style banner
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Profitez de réductions !",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Jusqu'à -50% sur une sélection d'articles.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // Compte à rebours
              _DynamicCountdown(endDate: DateTime.now().add(const Duration(days: 2))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => onCategorySelected("Promotions"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005260), // Cyan foncé pour le bouton
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Bouton pilule
                  ),
                ),
                child: const Text(
                  "Découvrez",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "*Dès 30€, jusqu'au 15/02.",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        
        // 2. Bannière Violette "Vente Live" (pour événement)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF440099), // Violet eBay
            borderRadius: BorderRadius.circular(0), // Bord à bord ou rectangle
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Rendez-vous le 4 février à 19h",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Une sélection d'articles de luxe spéciale Saint-Valentin à ne pas manquer !",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Action pour la vente live
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF440099),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Accéder à la vente Live",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget Countdown dynamique avec Timer
class _DynamicCountdown extends StatefulWidget {
  final DateTime endDate;

  const _DynamicCountdown({required this.endDate});

  @override
  State<_DynamicCountdown> createState() => _DynamicCountdownState();
}

class _DynamicCountdownState extends State<_DynamicCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    // Mise à jour chaque seconde
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemaining();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (now.isBefore(widget.endDate)) {
      setState(() {
        _remaining = widget.endDate.difference(now);
      });
    } else {
      setState(() {
        _remaining = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.inSeconds <= 0) {
      return const Text("Expiré", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
    }

    return Row(
      children: [
        _buildTimeUnit(_remaining.inHours, "H"),
        const Text(" : ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        _buildTimeUnit(_remaining.inMinutes % 60, "M"),
        const Text(" : ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        _buildTimeUnit(_remaining.inSeconds % 60, "S"),
      ],
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "${value.toString().padLeft(2, '0')}$label",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
