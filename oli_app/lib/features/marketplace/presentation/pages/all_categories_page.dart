import 'package:flutter/material.dart';
import 'market_view.dart';

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({super.key});

  // Liste alignée avec MarketView
  final List<Map<String, dynamic>> categories = const [
    {"label": "Industrie", "icon": Icons.factory, "color": Color(0xFFE3F2FD)}, // Blue 50
    {"label": "Maison", "icon": Icons.chair, "color": Color(0xFFF3E5F5)}, // Purple 50
    {"label": "Véhicules", "icon": Icons.directions_car, "color": Color(0xFFE8F5E9)}, // Green 50
    {"label": "Mode", "icon": Icons.checkroom, "color": Color(0xFFFCE4EC)}, // Pink 50
    {"label": "Électronique", "icon": Icons.phone_android, "color": Color(0xFFE0F7FA)}, // Cyan 50
    {"label": "Sports", "icon": Icons.sports_soccer, "color": Color(0xFFFFF3E0)}, // Orange 50
    {"label": "Beauté", "icon": Icons.face, "color": Color(0xFFFAEFE6)}, 
    {"label": "Jouets", "icon": Icons.toys, "color": Color(0xFFFFFDE7)}, // Yellow 50
    {"label": "Santé", "icon": Icons.medical_services, "color": Color(0xFFE0F2F1)}, // Teal 50
    {"label": "Construction", "icon": Icons.construction, "color": Color(0xFFECEFF1)}, // BlueGrey 50
    {"label": "Outils", "icon": Icons.build, "color": Color(0xFFEFEBE9)}, // Brown 50
    {"label": "Bureau", "icon": Icons.desk, "color": Color(0xFFFAFAFA)},
    {"label": "Jardin", "icon": Icons.grass, "color": Color(0xFFF1F8E9)}, // LightGreen 50
    {"label": "Animaux", "icon": Icons.pets, "color": Color(0xFFFFF8E1)}, // Amber 50
    {"label": "Bébé", "icon": Icons.child_friendly, "color": Color(0xFFF3E5F5)}, 
    {"label": "Alimentation", "icon": Icons.restaurant, "color": Color(0xFFFFEBEE)}, // Red 50
    {"label": "Sécurité", "icon": Icons.security, "color": Color(0xFFE8EAF6)}, // Indigo 50
    {"label": "Autres", "icon": Icons.category, "color": Color(0xFFEEEEEE)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, 
          crossAxisSpacing: 15,
          mainAxisSpacing: 20,
          childAspectRatio: 0.85, // Plus haut pour le texte
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return InkWell(
            onTap: () {
              // Navigation vers MarketView avec le filtre pré-activé
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => MarketView(initialCategoryLabel: cat['label'])
                )
              );
            },
            borderRadius: BorderRadius.circular(15),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cat['color'],
                      borderRadius: BorderRadius.circular(20),
                      // Petite ombre douce
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(cat['icon'], size: 35, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cat['label'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                    color: Colors.black87
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
