import 'package:flutter/material.dart';

class ProductActionButtons extends StatelessWidget {
  final VoidCallback onBuyNow;
  final VoidCallback onAddToCart;
  final VoidCallback onToggleFollow;
  final bool isFollowing;

  const ProductActionButtons({
    super.key,
    required this.onBuyNow,
    required this.onAddToCart,
    required this.onToggleFollow,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
              onPressed: onBuyNow,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7DBA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: const Text("Achat immédiat",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white))),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
              onPressed: onAddToCart,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: const Text("Ajouter au panier",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white))),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
              onPressed: onToggleFollow,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isFollowing ? Colors.blueAccent : Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: Text(isFollowing ? "OBJET SUIVI" : "Suivre cet objet",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isFollowing ? Colors.blueAccent : Colors.white))),
        ),
      ],
    );
  }
}
