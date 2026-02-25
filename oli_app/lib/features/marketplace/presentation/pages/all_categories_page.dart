import 'package:flutter/material.dart';
import 'market_view.dart';

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({super.key});

  // Liste alignée avec MarketView - Design Premium 3D Icons
  final List<Map<String, dynamic>> categories = const [
    {"label": "Industrie", "icon": Icons.factory, "image": "assets/images/categories/industry.png"},
    {"label": "Maison", "icon": Icons.chair, "image": "assets/images/categories/home.png"},
    {"label": "Véhicules", "icon": Icons.directions_car, "image": "assets/images/categories/vehicles.png"},
    {"label": "Mode", "icon": Icons.checkroom, "image": "assets/images/categories/fashion.png"},
    {"label": "Électronique", "icon": Icons.phone_android, "image": "assets/images/categories/electronics.png"},
    {"label": "Sports", "icon": Icons.sports_soccer, "image": "assets/images/categories/sports.png"},
    {"label": "Beauté", "icon": Icons.face, "image": "assets/images/categories/beauty.png"}, 
    {"label": "Jouets", "icon": Icons.toys, "image": "assets/images/categories/toys.png"},
    {"label": "Santé", "icon": Icons.medical_services, "image": "assets/images/categories/health.png"},
    {"label": "Construction", "icon": Icons.construction, "image": "assets/images/categories/construction.png"},
    {"label": "Outils", "icon": Icons.build, "image": "assets/images/categories/tools.png"},
    {"label": "Bureau", "icon": Icons.desk, "image": "assets/images/categories/office.png"},
    {"label": "Jardin", "icon": Icons.grass, "image": "assets/images/categories/garden.png"},
    {"label": "Animaux", "icon": Icons.pets, "image": "assets/images/categories/pets.png"},
    {"label": "Bébé", "icon": Icons.child_friendly, "image": "assets/images/categories/baby.png"}, 
    {"label": "Alimentation", "icon": Icons.restaurant, "image": "assets/images/categories/food.png"},
    {"label": "Sécurité", "icon": Icons.security, "image": "assets/images/categories/security.png"},
    {"label": "Autres", "icon": Icons.category, "image": "assets/images/categories/other.png"},
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
                  builder: (_) => MarketView(initialCategoryLabel: cat['label'])
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
