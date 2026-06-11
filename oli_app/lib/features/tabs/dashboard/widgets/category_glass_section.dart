
import 'package:flutter/material.dart';
import 'dart:ui'; // Pour BackdropFilter

class CategoryGlassSection extends StatefulWidget {
  final Map<String, String> categories;
  final Function(String) onCategorySelected;
  final String selectedCategory;

  const CategoryGlassSection({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategory,
    required this.categories,
  });

  @override
  State<CategoryGlassSection> createState() => _CategoryGlassSectionState();
}

class _CategoryGlassSectionState extends State<CategoryGlassSection> {

  /// Images PNG par catégorie (label FR → chemin asset)
  static const Map<String, String> _categoryImages = {
    'Électronique': 'assets/images/categories/electronics.png',
    'Mode': 'assets/images/categories/fashion.png',
    'Maison': 'assets/images/categories/home.png',
    'Alimentation': 'assets/images/categories/food.png',
    'Beauté': 'assets/images/categories/beauty.png',
    'Industrie': 'assets/images/categories/industry.png',
    'Sports': 'assets/images/categories/sports.png',
    'Outils': 'assets/images/categories/tools.png',
    'Construction': 'assets/images/categories/construction.png',
    'Autres': 'assets/images/categories/other.png',
    'Véhicules': 'assets/images/categories/vehicles.png',
    'Jouets': 'assets/images/categories/toys.png',
    'Sécurité': 'assets/images/categories/security.png',
    'Jardin': 'assets/images/categories/garden.png',
    'Bébé': 'assets/images/categories/baby.png',
    'Bureau': 'assets/images/categories/office.png',
    'Animaux': 'assets/images/categories/pets.png',
    'Santé': 'assets/images/categories/health.png',
  };

  /// Icônes Material de fallback (si PNG manquant)
  static const Map<String, IconData> _categoryIcons = {
    'Électronique': Icons.phone_android,
    'Mode': Icons.checkroom,
    'Maison': Icons.chair,
    'Alimentation': Icons.restaurant,
    'Beauté': Icons.face,
    'Industrie': Icons.factory,
    'Sports': Icons.sports_soccer,
    'Outils': Icons.build,
    'Construction': Icons.construction,
    'Autres': Icons.category,
    'Véhicules': Icons.directions_car,
    'Jouets': Icons.toys,
    'Sécurité': Icons.security,
    'Jardin': Icons.grass,
    'Bébé': Icons.child_friendly,
    'Bureau': Icons.desk,
    'Animaux': Icons.pets,
    'Santé': Icons.medical_services,
    'Tout': Icons.apps,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.categories.keys.length,
        itemBuilder: (context, index) {
          final label = widget.categories.keys.elementAt(index);
          final isSelected = widget.selectedCategory == label;
          return GestureDetector(
            onTap: () => widget.onCategorySelected(label),
            child: _buildCategoryChip(label, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    final imagePath = _categoryImages[label];
    final iconData = _categoryIcons[label] ?? Icons.category;

    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cercle icône ───────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.orange : Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.35)
                      : Colors.black.withOpacity(0.15),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.withOpacity(0.12)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.orange.withOpacity(0.5)
                      : Colors.black12,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(9.0),
                child: imagePath != null
                    ? Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          iconData,
                          color: isSelected ? Colors.orange : Colors.black54,
                          size: 24,
                        ),
                      )
                    : Icon(
                        iconData,
                        color: isSelected ? Colors.orange : Colors.black54,
                        size: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ── Label ──────────────────────────────────────────────────
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 9.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // ── Point indicateur de sélection ──────────────────────────
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 5 : 0,
            height: isSelected ? 5 : 0,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
