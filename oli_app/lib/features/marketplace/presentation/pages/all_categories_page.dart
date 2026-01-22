import 'package:flutter/material.dart';

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({super.key});

  final List<Map<String, dynamic>> categories = const [
    {"label": "Industrie", "icon": Icons.factory},
    {"label": "Maison", "icon": Icons.chair},
    {"label": "Véhicules", "icon": Icons.directions_car},
    {"label": "Mode", "icon": Icons.checkroom},
    {"label": "Électronique", "icon": Icons.phone_android},
    {"label": "Sports", "icon": Icons.sports_soccer},
    {"label": "Beauté", "icon": Icons.face},
    {"label": "Jouets", "icon": Icons.toys},
    {"label": "Santé", "icon": Icons.medical_services},
    {"label": "Construction", "icon": Icons.construction},
    {"label": "Électricité", "icon": Icons.lightbulb},
    {"label": "Outils", "icon": Icons.build},
    {"label": "Emballage", "icon": Icons.inventory_2},
    {"label": "Bureau", "icon": Icons.desk},
    {"label": "Jardin", "icon": Icons.grass},
    {"label": "Animaux", "icon": Icons.pets},
    {"label": "Bébé", "icon": Icons.child_friendly},
    {"label": "Alimentation", "icon": Icons.restaurant},
    {"label": "Agriculture", "icon": Icons.agriculture},
    {"label": "Sécurité", "icon": Icons.security},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Toutes les catégories", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 colonnes comme Alibaba/Amazon
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return InkWell(
            onTap: () {
              // TODO: Naviguer vers MarketView avec filtre catégorie
              // Pour l'instant on retourne juste
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Filtre : ${cat['label']}")),
              );
              Navigator.pop(context, cat['label']);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat['icon'], size: 32, color: Colors.blueAccent),
                  const SizedBox(height: 8),
                  Text(
                    cat['label'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
