import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'package:image_picker/image_picker.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  const ProductDetailsPage({super.key, required this.product});
  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(children: [
          Stack(children: [
            Container(
              color: Colors.white,
              height: 400,
              width: double.infinity,
              child: p.images.isEmpty
                  ? const Center(child: Icon(Icons.image, size: 60, color: Colors.grey))
                  : PageView.builder(
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemCount: p.images.length,
                      itemBuilder: (c, i) => kIsWeb 
                        ? Image.network(p.images[i].path, fit: BoxFit.cover)
                        : Image.file(io.File(p.images[i].path), fit: BoxFit.cover),
                    ),
            ),
            Positioned(
              top: 40, left: 16,
              child: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18), onPressed: () => Navigator.pop(context))),
            ),
            Positioned(
              top: 40, right: 16,
              child: Row(children: [
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: const Icon(Icons.ios_share, color: Colors.black, size: 18)),
                const SizedBox(width: 10),
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: const Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 18)),
              ]),
            ),
            if (p.images.length > 1)
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(p.images.length, (i) => Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: i == _currentImageIndex ? Colors.blueAccent : Colors.grey.withOpacity(0.5))))),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(p.name.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          // BLOC VENDEUR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Stack(
                children: [
                   CircleAvatar(radius: 25, backgroundColor: Colors.blueAccent, child: Text(p.seller[0], style: const TextStyle(color: Colors.white, fontSize: 20))),
                   Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.blue, size: 16))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.seller.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                  Text('${p.totalBuyerRatings}% d\'évaluation positive', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 30),
            ]),
          ),
          // BANNIÈRE PRIX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: const Color(0xFF1E7DBA),
            child: Center(child: Text("${p.price}\$", style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${p.deliveryPrice}\$ de livraison", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text("Livraison estimée : ${p.deliveryTime}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Divider(color: Colors.white24, height: 24),
              Text("Etat : ${p.condition}", style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              // BOUTONS D'ACTION
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E7DBA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Achat immédiat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Ajouter au panier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text("Suivre cet objet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
              ),
              const SizedBox(height: 20),
              GestureDetector(onTap: () {}, child: const Text("Afficher la description complète", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline))),
              const SizedBox(height: 8),
              Text("Quantité Disponible : ${p.quantity}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}
