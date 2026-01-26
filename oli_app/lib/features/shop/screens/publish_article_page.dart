import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import '../../marketplace/providers/market_provider.dart';
import '../providers/product_controller.dart';
import '../../../models/product_model.dart';
import '../../../config/api_config.dart';

class PublishArticlePage extends ConsumerStatefulWidget {
  const PublishArticlePage({super.key});
  @override
  ConsumerState<PublishArticlePage> createState() => _PublishArticlePageState();
}

class _PublishArticlePageState extends ConsumerState<PublishArticlePage> {
  List<XFile> _images = [];
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _deliveryPrice = TextEditingController();
  final TextEditingController _deliveryTime = TextEditingController();
  final TextEditingController _color = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  String _condition = 'Neuf';
  String _category = 'Électronique'; // Nouvelle catégorie par défaut
  final _formKey = GlobalKey<FormState>();

  // Liste des catégories disponibles
  // Liste complète des catégories avec assets
  final List<Map<String, dynamic>> _categoriesData = [
    {"label": "Électronique", "icon": Icons.phone_android, "image": "assets/images/categories/electronics.png"},
    {"label": "Mode", "icon": Icons.checkroom, "image": "assets/images/categories/fashion.png"},
    {"label": "Maison", "icon": Icons.chair, "image": "assets/images/categories/home.png"},
    {"label": "Véhicules", "icon": Icons.directions_car, "image": "assets/images/categories/vehicles.png"},
    {"label": "Industrie", "icon": Icons.factory, "image": "assets/images/categories/industry.png"},
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
    {"label": "Alimentation", "icon": Icons.restaurant, "image": null},
    {"label": "Sécurité", "icon": Icons.security, "image": null},
    {"label": "Autres", "icon": Icons.category, "image": null},
  ];

  String? _location;
  bool _gettingLocation = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La localisation est désactivée')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission de localisation refusée')));
            return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission de localisation définitivement refusée')));
          return;
      }

      // LocationSettings pour plus de précision et un timeout
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings
      ).timeout(const Duration(seconds: 10)); // Timeout de 10s
      setState(() {
        // Format simple: "Lat, Long". Idéalement utiliser Geocoding pour avoir une adresse
        _location = "${position.latitude}, ${position.longitude}"; 
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Position acquise: $_location')));

    } catch (e) {
      debugPrint("Erreur localisation: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur récupération position')));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    final imgs = await ImagePicker().pickMultiImage();
    if (imgs.isNotEmpty && _images.length < 8) {
      setState(() {
        _images.addAll(imgs.take(8 - _images.length));
      });
    }
  }

  void _removeImage(int idx) => setState(() => _images.removeAt(idx));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Vendre un article (DIO-V2)"), 
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, size: 12),
            onPressed: () => debugPrint("🚀 Mode: Dio V2 | Base: ${ApiConfig.baseUrl}"),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const Text('Photos (1-8)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _images.isEmpty
                ? GestureDetector(
                    onTap: _pickImages,
                    child: Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent)), child: const Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.blueAccent))),
                  )
                : Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: _images.length + (_images.length < 8 ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i == _images.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent)), child: const Icon(Icons.add, color: Colors.blueAccent)),
                            );
                          }
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb
                                    ? Image.network(
                                        _images[i].path,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : FutureBuilder<Uint8List>(
                                        future: _images[i].readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            );
                                          }
                                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                        },
                                      ),
                              ),
                              Positioned(
                                top: 0, right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            TextFormField(controller: _name, validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nom du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _price, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Prix requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Prix (\$)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            // NOUVELLE CATÉGORIE DROPDOWN
            // NOUVEAU SÉLECTEUR DE CATÉGORIE (Glassmorphism + 3D)
            const Text("Catégorie", style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100, // Hauteur suffisante pour icon + texte
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categoriesData.length,
                separatorBuilder: (c, i) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final cat = _categoriesData[index];
                  final label = cat['label'];
                  final isSelected = _category == label;
                  final hasImage = cat['image'] != null;

                  return GestureDetector(
                    onTap: () => setState(() => _category = label),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WIDGET GLASSMORPHISM
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Intensité du flou
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent.withOpacity(0.4) : Colors.white.withOpacity(0.1), // Teinte vitreuse
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.3), // Bordure fine pour le relief (Bleu si sélectionné)
                                  width: isSelected ? 2 : 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0), // Padding pour l'image
                                child: hasImage
                                  ? Image.asset(cat['image'], fit: BoxFit.contain)
                                  : Icon(
                                      cat['icon'],
                                      color: Colors.white.withOpacity(0.9),
                                      size: 30,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Label en dessous
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.blueAccent : Colors.white70,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(controller: _deliveryPrice, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Coût de livraison requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Coût de livraison (\$)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _deliveryTime, validator: (v) => v == null || v.trim().isEmpty ? 'Temps requis' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Temps de livraison (ex: 2-3 jours)", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(controller: _color, validator: (v) => v == null || v.trim().isEmpty ? 'Couleur requise' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Couleur", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _condition,
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(labelText: "État du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder()),
              items: ['Neuf', 'Bon état', 'État acceptable', 'À restaurer'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 15),
            TextFormField(controller: _quantity, keyboardType: TextInputType.number, validator: (v) => v == null || v.trim().isEmpty ? 'Quantité requise' : null, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantité disponible", filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextFormField(
              controller: _description,
              maxLines: 4,
              validator: (v) => v == null || v.trim().isEmpty ? 'Description requise' : null,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Description du produit", filled: true, fillColor: Colors.white10, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            // UI Bouton Localisation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _location ?? "Ajouter ma position actuelle",
                      style: TextStyle(color: _location != null ? Colors.white : Colors.white54),
                    ),
                  ),
                  if (_gettingLocation)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text("Obtenir"),
                    )
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_images.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins une photo')));
                          return;
                        }
                        final ok = await ref.read(productControllerProvider.notifier).uploadProduct(
                          name: _name.text.trim(),
                          price: _price.text.trim(),
                          description: _description.text.trim(),
                          deliveryPrice: double.tryParse(_deliveryPrice.text.trim()) ?? 0,
                          deliveryTime: _deliveryTime.text.trim(),
                          condition: _condition,
                          quantity: int.tryParse(_quantity.text.trim()) ?? 1,
                          color: _color.text.trim(),
                          images: _images,
                          category: _category, 
                          location: _location, 
                        );
                        if (ok) {
                          ref.read(marketProductsProvider.notifier).fetchProducts();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article publié avec succès')));
                            Navigator.pop(context);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec de la publication')));
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: state.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLIER"),
              ),
            ),
          ]),
        ),
      ),
    );
  }


}
