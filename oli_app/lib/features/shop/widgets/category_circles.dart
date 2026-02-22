import 'package:flutter/material.dart';

/// Widget circulaires de catégories (style eBay)
class CategoryCircles extends StatelessWidget {
  final String title;
  final Function(String category)? onCategorySelected;
  final List<Map<String, dynamic>>? customCategories;

  const CategoryCircles({
    super.key,
    this.title = "Populaire sur la boutique",
    this.onCategorySelected,
    this.customCategories,
  });

  List<Map<String, dynamic>> get _defaultCategories => [
    {
      'label': 'Électronique', 
      'key': 'electronics',
      'image': 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=500&q=80', 
      'color': const Color(0xFF3665F3)
    },
    {
      'label': 'Mode', 
      'key': 'fashion',
      'image': 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=500&q=80', 
      'color': const Color(0xFFE53238)
    },
    {
      'label': 'Véhicules', 
      'key': 'vehicles',
      'image': 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?w=500&q=80', 
      'color': const Color(0xFFF5AF02)
    },
    {
      'label': 'Maison', 
      'key': 'home',
      'image': 'https://images.unsplash.com/photo-1484154218962-a1c002085aac?w=500&q=80', 
      'color': const Color(0xFF86B817)
    },
  ];

  @override
  Widget build(BuildContext context) {
    final categories = customCategories ?? _defaultCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: GestureDetector(
                  onTap: () => onCategorySelected?.call(cat['label'] as String),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cat['color'] as Color,
                            width: 2,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(cat['image'] as String),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 90,
                        child: Text(
                          cat['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
