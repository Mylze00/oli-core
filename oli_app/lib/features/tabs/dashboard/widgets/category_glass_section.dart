
import 'package:flutter/material.dart';
import 'dart:ui'; // Pour BackdropFilter

class CategoryGlassSection extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String selectedCategory;

  const CategoryGlassSection({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategory,
  });

  @override
  State<CategoryGlassSection> createState() => _CategoryGlassSectionState();
}

class _CategoryGlassSectionState extends State<CategoryGlassSection> {
  final Map<String, String> _categories = {
    "Tout": "",
    "Industrie": "industry",
    "Maison": "home",
    "Véhicules": "vehicles",
    "Mode": "fashion",
    "Électronique": "electronics",
    "Beauté": "beauty",
    "Enfants": "kids",
  };

  final Map<String, String> _categoryImages = {
    "Industrie": "assets/images/categories/industry.png",
    "Maison": "assets/images/categories/home.png",
    "Véhicules": "assets/images/categories/vehicles.png",
    "Mode": "assets/images/categories/fashion.png",
    "Électronique": "assets/images/categories/electronics.png",
    "Beauté": "assets/images/categories/beauty.png",
    "Enfants": "assets/images/categories/kids.png",
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90, // Hauteur suffisante pour les chips
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.keys.length,
        itemBuilder: (context, index) {
          final label = _categories.keys.elementAt(index);
          return GestureDetector(
            onTap: () => widget.onCategorySelected(label),
            child: _buildCategoryChip(label, widget.selectedCategory == label),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    final imagePath = _categoryImages[label];
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          // WIDGET GLASSMORPHISM AVEC DOUBLE BORDURE (NOIR PUIS BLANC)
          Container(
            padding: const EdgeInsets.all(2), // Espace pour la bordure blanche extérieure
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2), // Bordure Blanche Extérieure
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: Container(
              width: 56, // Taille alignée
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white, // Fond Blanc
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1), // Bordure Noir Intérieure
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0), // Padding augmenté à 10.0 pour éviter que l'image ne touche les bords
                child: imagePath != null
                  ? Image.asset(imagePath, fit: BoxFit.contain)
                  : Icon(Icons.category, color: Colors.black54, size: 26.0),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            )
          ),
        ],
      ),
    );
  }
}
