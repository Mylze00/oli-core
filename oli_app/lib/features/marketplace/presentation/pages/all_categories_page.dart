import 'package:flutter/material.dart';
import 'category_products_page.dart';

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({super.key});

  // Liste alignée avec MarketView - Design Premium 3D Icons
  final List<Map<String, dynamic>> categories = const [
    {"label": "Industrie", "key": "industry", "icon": Icons.factory, "image": "assets/images/categories/industry.png"},
    {"label": "Maison", "key": "home", "icon": Icons.chair, "image": "assets/images/categories/home.png"},
    {"label": "Véhicules", "key": "vehicles", "icon": Icons.directions_car, "image": "assets/images/categories/vehicles.png"},
    {"label": "Mode", "key": "fashion", "icon": Icons.checkroom, "image": "assets/images/categories/fashion.png"},
    {"label": "Électronique", "key": "electronics", "icon": Icons.phone_android, "image": "assets/images/categories/electronics.png"},
    {"label": "Sports", "key": "sports", "icon": Icons.sports_soccer, "image": "assets/images/categories/sports.png"},
    {"label": "Beauté", "key": "beauty", "icon": Icons.face, "image": "assets/images/categories/beauty.png"}, 
    {"label": "Jouets", "key": "toys", "icon": Icons.toys, "image": "assets/images/categories/toys.png"},
    {"label": "Santé", "key": "health", "icon": Icons.medical_services, "image": "assets/images/categories/health.png"},
    {"label": "Construction", "key": "construction", "icon": Icons.construction, "image": "assets/images/categories/construction.png"},
    {"label": "Outils", "key": "tools", "icon": Icons.build, "image": "assets/images/categories/tools.png"},
    {"label": "Bureau", "key": "office", "icon": Icons.desk, "image": "assets/images/categories/office.png"},
    {"label": "Jardin", "key": "garden", "icon": Icons.grass, "image": "assets/images/categories/garden.png"},
    {"label": "Animaux", "key": "pets", "icon": Icons.pets, "image": "assets/images/categories/pets.png"},
    {"label": "Bébé", "key": "baby", "icon": Icons.child_friendly, "image": "assets/images/categories/baby.png"}, 
    {"label": "Alimentation", "key": "food", "icon": Icons.restaurant, "image": "assets/images/categories/food.png"},
    {"label": "Sécurité", "key": "security", "icon": Icons.security, "image": "assets/images/categories/security.png"},
    {"label": "Autres", "key": "other", "icon": Icons.category, "image": "assets/images/categories/other.png"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fond blanc premium
      appBar: AppBar(
        title: const Text("Nos Catégories", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24), // Padding généreux
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, 
          crossAxisSpacing: 20, // Espacement aéré
          mainAxisSpacing: 24,
          childAspectRatio: 0.8, // Plus vertical pour l'image et texte
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final hasImage = cat['image'] != null;
          
          return InkWell(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => CategoryProductsPage(
                    categoryKey: cat['key'],
                    categoryLabel: cat['label'],
                    categoryIcon: cat['icon'],
                  ),
                )
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasImage ? Colors.transparent : const Color(0xFFF5F5F5), // Pas de fond si image (fond blanc de l'image)
                      borderRadius: BorderRadius.circular(24),
                      // Ombre subtile si pas d'image, ou aucune si image (effet flat 3D)
                    ),
                    child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(cat['image'], fit: BoxFit.contain)
                        )
                      : Center(
                          child: Icon(cat['icon'], size: 35, color: Colors.grey[700]),
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cat['label'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.3
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
