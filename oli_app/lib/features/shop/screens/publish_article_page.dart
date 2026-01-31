import 'dart:io'; // Import for File
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../marketplace/providers/market_provider.dart';
import '../providers/product_controller.dart';
import '../../../config/api_config.dart';

class PublishArticlePage extends ConsumerStatefulWidget {
  const PublishArticlePage({super.key});
  @override
  ConsumerState<PublishArticlePage> createState() => _PublishArticlePageState();
}

class _PublishArticlePageState extends ConsumerState<PublishArticlePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs
  List<XFile> _images = [];
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _color = TextEditingController();
  
  // Livraison
  bool _enableExpress = false;
  bool _enableOrdinary = true;
  final TextEditingController _expressPrice = TextEditingController();
  final TextEditingController _ordinaryPrice = TextEditingController();
  final TextEditingController _deliveryTime = TextEditingController();

  String _condition = 'Neuf';
  String _category = 'Électronique';
  String? _location;
  bool _gettingLocation = false;

  final List<Map<String, dynamic>> _categoriesData = [
    {"label": "Électronique", "icon": Icons.phone_android, "image": "assets/images/categories/electronics.png"},
    {"label": "Mode", "icon": Icons.checkroom, "image": "assets/images/categories/fashion.png"},
    {"label": "Maison", "icon": Icons.chair, "image": "assets/images/categories/home.png"},
    {"label": "Véhicules", "icon": Icons.directions_car, "image": "assets/images/categories/vehicles.png"},
    {"label": "Sports", "icon": Icons.sports_soccer, "image": "assets/images/categories/sports.png"},
    {"label": "Autres", "icon": Icons.category, "image": null},
  ];

  /// Gère la récupération de la localisation
  Future<bool> _handleLocationRequest() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      ).timeout(const Duration(seconds: 8));

      setState(() => _location = "${position.latitude},${position.longitude}");
      return true;
    } catch (e) {
      debugPrint("Erreur localisation: $e");
      return false;
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (imgs.isNotEmpty && _images.length < 8) {
      setState(() => _images.addAll(imgs.take(8 - _images.length)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Mettre en vente", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildImagePicker(),
            const SizedBox(height: 20),
            
            _buildTextField(_name, "Nom du produit", Icons.shopping_bag),
            _buildTextField(_price, "Prix de vente (\$)", Icons.attach_money, isNumber: true),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Catégorie", style: TextStyle(color: Colors.white70)),
            ),
            _buildCategorySelector(),
            
            const SizedBox(height: 20),
            _buildConditionDropdown(),
            
            const SizedBox(height: 20),
            _buildSectionTitle("Options de livraison"),
            _buildDeliveryOptions(),

            const SizedBox(height: 20),
            _buildTextField(_description, "Description détaillée", Icons.description, maxLines: 3),
            _buildTextField(_quantity, "Quantité en stock", Icons.inventory, isNumber: true),
            _buildTextField(_color, "Couleur(s)", Icons.palette),

            const SizedBox(height: 30),
            _buildPublishButton(state),
          ]),
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        style: const TextStyle(color: Colors.white),
        validator: (v) => v!.isEmpty ? "Champ requis" : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildConditionDropdown() {
    return DropdownButtonFormField<String>(
      value: _condition,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: "État du produit",
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['Neuf', 'Bon état', 'Acceptable', 'À restaurer'].map((v) {
        return DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white)));
      }).toList(),
      onChanged: (v) => setState(() => _condition = v!),
    );
  }

  Widget _buildDeliveryOptions() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        CheckboxListTile(
          title: const Text("Livraison Ordinaire (Oli Logistic)", style: TextStyle(color: Colors.white)),
          value: _enableOrdinary,
          activeColor: Colors.blueAccent,
          onChanged: (v) => setState(() => _enableOrdinary = v!),
        ),
        if (_enableOrdinary)
          _buildTextField(_ordinaryPrice, "Frais de port Ordinaire (\$)", Icons.local_shipping, isNumber: true),
        
        const Divider(color: Colors.white24),
        
        CheckboxListTile(
          title: const Text("Livraison Express (24h)", style: TextStyle(color: Colors.orangeAccent)),
          value: _enableExpress,
          activeColor: Colors.orangeAccent,
          onChanged: (v) => setState(() => _enableExpress = v!),
        ),
        if (_enableExpress)
          _buildTextField(_expressPrice, "Frais de port Express (\$)", Icons.bolt, isNumber: true),
          
        _buildTextField(_deliveryTime, "Temps estimé (ex: 2-3 jours)", Icons.timer),
      ]),
    );
  }

  Widget _buildImagePicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Photos du produit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length + 1,
          itemBuilder: (context, i) {
            if (i == _images.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
                  child: const Icon(Icons.add_a_photo, color: Colors.blueAccent),
                ),
              );
            }
            return Stack(children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: kIsWeb 
                        ? NetworkImage(_images[i].path) 
                        : FileImage(File(_images[i].path)) as ImageProvider, // Corrected Usage
                    fit: BoxFit.cover
                  ),
                ),
              ),
              Positioned(right: 15, top: 5, child: GestureDetector(onTap: () => setState(() => _images.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoriesData.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = _categoriesData[index];
          final isSelected = _category == cat['label'];
          // Helper to get image safety
          final imageAsset = cat['image'] as String?;
          
          return GestureDetector(
            onTap: () => setState(() => _category = cat['label']),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent : Colors.white10,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: imageAsset != null 
                    ? Image.asset(imageAsset, width: 24, height: 24, color: isSelected ? Colors.white : Colors.white54)
                    : Icon(cat['icon'], color: isSelected ? Colors.white : Colors.white54),
              ),
              const SizedBox(height: 5),
              Text(
                  cat['label'], 
                  style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white54, fontSize: 10)
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildPublishButton(dynamic state) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: state.isLoading ? null : _submitForm,
        child: state.isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : Text(_gettingLocation ? "LOCALISATION..." : "PUBLIER L'ARTICLE"),
      ),
    );
  }

  // --- LOGIQUE DE SOUMISSION ---

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajoutez au moins une photo")));
      return;
    }
    if (!_enableExpress && !_enableOrdinary) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez au moins un mode de livraison")));
      return;
    }

    // Localisation automatique au moment du clic
    if (_location == null) {
      bool success = await _handleLocationRequest();
      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La localisation est requise pour calculer les frais de livraison")));
        return;
      }
    }

    // Protection contre les valeurs vides 
    final ordinaryPriceVal = double.tryParse(_ordinaryPrice.text) ?? 0;
    final expressPriceVal = _enableExpress ? (double.tryParse(_expressPrice.text) ?? 0) : null;
    final deliveryTimeVal = _deliveryTime.text.trim();

    final ok = await ref.read(productControllerProvider.notifier).uploadProduct(
      name: _name.text.trim(),
      price: _price.text.trim(),
      description: _description.text.trim(),
      // On envoie les deux prix (le backend gérera les null/0)
      deliveryPrice: ordinaryPriceVal,
      expressPrice: expressPriceVal,
      deliveryTime: deliveryTimeVal.isEmpty ? "2-3 jours" : deliveryTimeVal, // Fallback
      condition: _condition,
      quantity: int.tryParse(_quantity.text) ?? 1,
      color: _color.text.trim(),
      images: _images,
      category: _category,
      location: _location,
    );

    if (ok && mounted) {
      ref.read(marketProductsProvider.notifier).fetchProducts();
      // On recharge aussi les produits "featured" pour être sûr
      ref.refresh(marketProductsProvider); 
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Article publié avec succès !")));
      Navigator.pop(context);
    }
  }
}
