import 'dart:io'; // Import for File
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart'; // Import Geocoding
import 'package:geolocator/geolocator.dart';
import '../../marketplace/providers/market_provider.dart';
import '../providers/product_controller.dart';
import '../../../config/api_config.dart';
import '../../../models/product_model.dart';

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
  
  // Livraison (Dynamic)
  List<ShippingOption> _shippingOptions = [
    ShippingOption(methodId: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', cost: 0.0)
  ];

  final List<Map<String, String>> _availableMethods = [
    {'id': 'oli_express', 'label': 'Oli Express', 'time': '1-2h'},
    {'id': 'oli_standard', 'label': 'Oli Standard', 'time': '2-5 jours'},
    {'id': 'partner', 'label': 'Livreur Partenaire', 'time': 'Variable'},
    {'id': 'hand_delivery', 'label': 'Remise en Main Propre', 'time': 'À convenir'},
    {'id': 'pick_go', 'label': 'Pick & Go', 'time': 'Retrait'},
    {'id': 'free', 'label': 'Livraison Gratuite', 'time': '3-7 jours'},
  ];

  String _condition = 'Neuf';
  String _category = 'Électronique';
  final TextEditingController _locationController = TextEditingController(); // Controller added
  bool _gettingLocation = false;

  final List<Map<String, dynamic>> _categoriesData = [
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
    {"label": "Alimentation", "icon": Icons.restaurant, "image": null},
    {"label": "Sécurité", "icon": Icons.security, "image": null},
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

      // Reverse Geocoding
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          // Build address prioritizing Commune/Neighborhood
          List<String> addressParts = [];
          
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!); // Souvent la Commune (ex: Gombe, Limete)
          } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }
          
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!); // Ville (ex: Kinshasa)
          }
          
          if (place.isoCountryCode != null && place.isoCountryCode!.isNotEmpty) {
            addressParts.add(place.isoCountryCode!);
          }
          
          if (addressParts.isNotEmpty) {
             final loc = addressParts.join(', ');
             setState(() => _locationController.text = loc);
          } else {
             final loc = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
             setState(() => _locationController.text = loc);
          }
        } else {
           final loc = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
           setState(() => _locationController.text = loc);
        }
      } catch (e) {
        debugPrint("Erreur Geocoding: $e");
        final loc = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        setState(() => _locationController.text = loc);
      }
      
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
        ..._shippingOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black12, 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: Colors.white24)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Option #${index + 1}", style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    if (_shippingOptions.length > 1)
                      GestureDetector(
                        onTap: () => setState(() => _shippingOptions.removeAt(index)),
                        child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _availableMethods.any((m) => m['id'] == option.methodId) ? option.methodId : null,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Mode de transport",
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  items: _availableMethods.map((m) {
                    return DropdownMenuItem(
                      value: m['id'],
                      child: Text(m['label']!, style: const TextStyle(fontSize: 13)), // Removed time display
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final selected = _availableMethods.firstWhere((m) => m['id'] == val);
                    setState(() {
                      _shippingOptions[index] = ShippingOption(
                        methodId: val,
                        label: selected['label']!,
                        time: selected['time']!,
                        cost: (val == 'free' || val == 'hand_delivery' || val == 'pick_go') ? 0.0 : option.cost,
                      );
                    });
                  },
                ),
                if (option.methodId != 'free' && option.methodId != 'hand_delivery' && option.methodId != 'pick_go' && option.methodId != 'partner') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField( // Cost Input
                          initialValue: option.cost > 0 ? option.cost.toString() : '',
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Coût (\$)",
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _shippingOptions[index] = ShippingOption(
                                methodId: option.methodId,
                                label: option.label,
                                time: option.time,
                                cost: double.tryParse(val) ?? 0.0,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField( // Time Input (Days)
                          initialValue: option.time,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Calcul du délai (jours)",
                            hintText: "Ex: 5",
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _shippingOptions[index] = ShippingOption(
                                methodId: option.methodId,
                                label: option.label,
                                time: val, // Store number as string
                                cost: option.cost,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[ // Cas gratuit / hand_delivery / pick_go / partner : Display Time only
                   const SizedBox(height: 10),
                   TextFormField( 
                    initialValue: option.time,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Temps estimé",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _shippingOptions[index] = ShippingOption(
                          methodId: option.methodId,
                          label: option.label,
                          time: val,
                          cost: option.cost, // 0.0
                        );
                      });
                    },
                   ),
                ]
              ],
            ),
          );
        }).toList(),
        
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
            label: const Text("Ajouter un mode de livraison", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () {
              setState(() {
                _shippingOptions.add(ShippingOption(
                  methodId: 'oli_standard', 
                  label: 'Oli Standard', 
                  time: '2-5 jours', 
                  cost: 0.0
                ));
              });
            },
          ),
        )
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
    return DropdownButtonFormField<String>(
      value: _categoriesData.any((c) => c['label'] == _category) ? _category : null,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: "Catégorie",
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
      items: _categoriesData.map((cat) {
        return DropdownMenuItem<String>(
          value: cat['label'],
          child: Text(cat['label'], style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _category = v!),
    );
  }

  Widget _buildLocationInput() {
    // Localisation Editable
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Row(children: [
        const Icon(Icons.location_on, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _locationController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Localisation (detectée ou manuelle)",
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_gettingLocation) 
          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
        else
          GestureDetector(
            onTap: _handleLocationRequest,
            child: const Icon(Icons.my_location, color: Colors.blueAccent),
          )
      ]),
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
    if (_shippingOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez au moins un mode de livraison")));
      return;
    }

    // Localisation automatique au moment du clic
    if (_locationController.text.isEmpty) { // Changed from _location == null
      bool success = await _handleLocationRequest();
      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La localisation est requise pour calculer les frais de livraison")));
        return;
      }
    }
    
    // Find default delivery price (lowest cost or first one)
    final defaultOption = _shippingOptions.first;

    final ok = await ref.read(productControllerProvider.notifier).uploadProduct(
      name: _name.text.trim(),
      price: _price.text.trim(),
      description: _description.text.trim(),
      deliveryPrice: defaultOption.cost,
      deliveryTime: defaultOption.time,
      expressPrice: null, // Deprecated logic
      condition: _condition,
      quantity: int.tryParse(_quantity.text) ?? 1,
      color: _color.text.trim(),
      images: _images,
      category: _category,
      location: _locationController.text.isEmpty ? "Inconnue" : _locationController.text,
      isNegotiable: false,
      shippingOptions: _shippingOptions,
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
