import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
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
  final TextEditingController _locationController = TextEditingController();
  bool _gettingLocation = false;

  // Nouveaux champs
  String _returnPolicy = 'Garantie Oli (7 jours)';
  bool _certifyAuthenticity = false;

  // Labels pour les slots photo
  static const List<Map<String, dynamic>> _photoSlots = [
    {'label': 'Face', 'icon': Icons.camera_front},
    {'label': 'Dos / Côté', 'icon': Icons.flip_camera_android},
    {'label': 'Étiquette', 'icon': Icons.label},
    {'label': 'Détail / Défaut', 'icon': Icons.search},
    {'label': 'Autre', 'icon': Icons.add_photo_alternate},
  ];

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

  // ────────────────── LISTENERS pour la barre de progression ──────────────────
  @override
  void initState() {
    super.initState();
    _name.addListener(_onFieldChanged);
    _price.addListener(_onFieldChanged);
    _description.addListener(_onFieldChanged);
    _quantity.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _quantity.dispose();
    _color.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ────────────────── CALCUL QUALITÉ ──────────────────
  double get _qualityScore {
    double score = 0;
    if (_name.text.trim().isNotEmpty) score += 15;
    if (_price.text.trim().isNotEmpty) score += 15;
    if (_images.isNotEmpty) score += _images.length >= 3 ? 25 : 15;
    if (_description.text.trim().isNotEmpty) score += 15;
    if (_category.isNotEmpty) score += 10;
    if (_locationController.text.trim().isNotEmpty) score += 10;
    if (_quantity.text.trim().isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  String get _qualityLabel {
    final s = _qualityScore;
    if (s >= 90) return "Excellente annonce ! 🌟";
    if (s >= 70) return "Bonne annonce 👍";
    if (s >= 40) return "Ajoutez plus de détails";
    return "Complétez votre annonce";
  }

  Color get _qualityColor {
    final s = _qualityScore;
    if (s >= 80) return Colors.greenAccent;
    if (s >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ────────────────── LOCALISATION ──────────────────
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

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          List<String> addressParts = [];
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.isoCountryCode != null && place.isoCountryCode!.isNotEmpty) {
            addressParts.add(place.isoCountryCode!);
          }
          if (addressParts.isNotEmpty) {
            setState(() => _locationController.text = addressParts.join(', '));
          } else {
            setState(() => _locationController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
          }
        } else {
          setState(() => _locationController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
        }
      } catch (e) {
        debugPrint("Erreur Geocoding: $e");
        setState(() => _locationController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
      }
      return true;
    } catch (e) {
      debugPrint("Erreur localisation: $e");
      return false;
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickImageForSlot(int slotIndex) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) {
      setState(() {
        if (slotIndex < _images.length) {
          _images[slotIndex] = img;
        } else {
          _images.add(img);
        }
      });
    }
  }

  Future<void> _pickMultipleImages() async {
    final imgs = await ImagePicker().pickMultiImage(imageQuality: 70);
    if (imgs.isNotEmpty && _images.length < 8) {
      setState(() => _images.addAll(imgs.take(8 - _images.length)));
    }
  }

  // ────────────────── DIALOGS D'AIDE ──────────────────
  void _showConditionHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("État du produit", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(emoji: "✨", title: "Neuf", desc: "Article jamais utilisé, dans son emballage d'origine."),
            SizedBox(height: 10),
            _HelpItem(emoji: "👍", title: "Occasion", desc: "Article déjà utilisé mais en bon état général."),
            SizedBox(height: 10),
            _HelpItem(emoji: "⚙️", title: "Fonctionnel", desc: "Article qui fonctionne correctement malgré des signes d'usure."),
            SizedBox(height: 10),
            _HelpItem(emoji: "🔧", title: "Pour pièce ou à réparer", desc: "Article endommagé, vendu pour récupération de pièces ou réparation."),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Compris"))],
      ),
    );
  }

  void _showDeliveryHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("Modes de livraison", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(emoji: "🚀", title: "Oli Express", desc: "Livraison rapide en 1-2h dans votre ville."),
            SizedBox(height: 8),
            _HelpItem(emoji: "📦", title: "Oli Standard", desc: "Livraison classique en 2-5 jours."),
            SizedBox(height: 8),
            _HelpItem(emoji: "🏍️", title: "Livreur Partenaire", desc: "Un livreur indépendant récupère le colis."),
            SizedBox(height: 8),
            _HelpItem(emoji: "🤝", title: "Remise en Main Propre", desc: "Rencontre directe avec l'acheteur."),
            SizedBox(height: 8),
            _HelpItem(emoji: "📍", title: "Pick & Go", desc: "L'acheteur retire en point relais."),
            SizedBox(height: 8),
            _HelpItem(emoji: "🎁", title: "Livraison Gratuite", desc: "Vous offrez la livraison."),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Compris"))],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
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
            
            // ─── BARRE DE PROGRESSION ───
            _buildProgressBar(),
            const SizedBox(height: 20),

            // ─── PHOTOS (GRILLE 5 SLOTS) ───
            _buildImageGrid(),
            const SizedBox(height: 20),
            
            // ─── CHAMPS PRINCIPAUX ───
            _buildTextField(_name, "Nom du produit", Icons.shopping_bag),
            _buildTextField(_price, "Prix de vente (\$)", Icons.attach_money, isNumber: true),
            _buildCategorySelector(),
            const SizedBox(height: 20),
            _buildConditionDropdown(),
            
            // ─── LIVRAISON ───
            const SizedBox(height: 20),
            _buildSectionTitleWithHelp("Options de livraison", _showDeliveryHelp),
            _buildDeliveryOptions(),

            // ─── DÉTAILS ───
            const SizedBox(height: 20),
            _buildTextField(_description, "Description détaillée", Icons.description, maxLines: 3),
            _buildTextField(_quantity, "Quantité en stock", Icons.inventory, isNumber: true),
            _buildTextField(_color, "Couleur(s)", Icons.palette),

            // ─── CONDITIONS DE VENTE ───
            const SizedBox(height: 20),
            _buildSaleConditions(),

            // ─── BOUCLIER DE CONFIANCE ───
            const SizedBox(height: 20),
            _buildTrustShield(),

            // ─── BOUTON PUBLIER ───
            const SizedBox(height: 24),
            _buildPublishButton(state),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════

  // ─── BARRE DE PROGRESSION ───
  Widget _buildProgressBar() {
    final score = _qualityScore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _qualityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Qualité de votre annonce", style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text("${score.toInt()}%", style: TextStyle(color: _qualityColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_qualityColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(_qualityLabel, style: TextStyle(color: _qualityColor, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── GRILLE PHOTOS 5 SLOTS ───
  Widget _buildImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Photos du produit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text("(${_images.length}/5+)", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Slots fixes (5)
            ...List.generate(5, (i) => _buildPhotoSlot(i)),
            // Bouton "+" pour photos supplémentaires si déjà 5+
            if (_images.length >= 5)
              GestureDetector(
                onTap: _pickMultipleImages,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.blueAccent, size: 24),
                      SizedBox(height: 4),
                      Text("Plus", style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Photos supplémentaires (au-delà des 5 slots)
        if (_images.length > 5) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length - 5,
              itemBuilder: (context, i) {
                final idx = i + 5;
                return Stack(children: [
                  Container(
                    width: 70, height: 70,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: kIsWeb ? NetworkImage(_images[idx].path) : FileImage(File(_images[idx].path)) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(right: 12, top: 2, child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(idx)),
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 10, color: Colors.white)),
                  )),
                ]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoSlot(int index) {
    final hasImage = index < _images.length;
    final slot = _photoSlots[index];

    return GestureDetector(
      onTap: () => _pickImageForSlot(index),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.greenAccent.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.3),
          ),
          image: hasImage
              ? DecorationImage(
                  image: kIsWeb
                      ? NetworkImage(_images[index].path)
                      : FileImage(File(_images[index].path)) as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasImage
            ? Stack(children: [
                Positioned(right: 4, top: 4, child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(index)),
                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 10, color: Colors.white)),
                )),
                Positioned(left: 4, bottom: 4, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(slot['label'], style: const TextStyle(color: Colors.white70, fontSize: 8)),
                )),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(slot['icon'], color: Colors.blueAccent.withOpacity(0.6), size: 24),
                  const SizedBox(height: 4),
                  Text(slot['label'], style: TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }

  // ─── CHAMPS TEXTE ───
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionTitleWithHelp(String title, VoidCallback onHelp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onHelp,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
              ),
              child: const Icon(Icons.question_mark, color: Colors.blueAccent, size: 14),
            ),
          ),
        ],
      ),
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

  // ─── CONDITION DROPDOWN + AIDE ───
  Widget _buildConditionDropdown() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
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
            items: ['Neuf', 'Occasion', 'Fonctionnel', 'Pour pièce ou à réparer'].map((v) {
              return DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white)));
            }).toList(),
            onChanged: (v) => setState(() => _condition = v!),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showConditionHelp,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: const Icon(Icons.question_mark, color: Colors.blueAccent, size: 16),
          ),
        ),
      ],
    );
  }

  // ─── LIVRAISON ───
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
                      child: Text(m['label']!, style: const TextStyle(fontSize: 13)),
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
                        child: TextFormField(
                          initialValue: option.cost > 0 ? option.cost.toString() : '',
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Coût (\$)",
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _shippingOptions[index] = ShippingOption(
                                methodId: option.methodId, label: option.label,
                                time: option.time, cost: double.tryParse(val) ?? 0.0,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: option.time,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Calcul du délai (jours)",
                            hintText: "Ex: 5",
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _shippingOptions[index] = ShippingOption(
                                methodId: option.methodId, label: option.label,
                                time: val, cost: option.cost,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextFormField( 
                    initialValue: option.time,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Temps estimé",
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _shippingOptions[index] = ShippingOption(
                          methodId: option.methodId, label: option.label,
                          time: val, cost: option.cost,
                        );
                      });
                    },
                  ),
                ]
              ],
            ),
          );
        }),
        
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
            label: const Text("Ajouter un mode de livraison", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () {
              setState(() {
                _shippingOptions.add(ShippingOption(
                  methodId: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', cost: 0.0
                ));
              });
            },
          ),
        )
      ]),
    );
  }

  // ─── CATÉGORIE ───
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

  // ─── CONDITIONS DE VENTE ───
  Widget _buildSaleConditions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Conditions de vente", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          
          // Politique de retour
          DropdownButtonFormField<String>(
            value: _returnPolicy,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: "Politique de retour",
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.assignment_return, color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              'Retours acceptés (sous 14 jours)',
              'Retours refusés',
              'Garantie Oli (7 jours)',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _returnPolicy = v!),
          ),
          
          const SizedBox(height: 16),
          
          // Certification authenticité
          GestureDetector(
            onTap: () => setState(() => _certifyAuthenticity = !_certifyAuthenticity),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _certifyAuthenticity ? Colors.greenAccent.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _certifyAuthenticity ? Colors.greenAccent.withOpacity(0.4) : Colors.white24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _certifyAuthenticity ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _certifyAuthenticity ? Colors.greenAccent : Colors.white38,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Je certifie que l'article est authentique et conforme à la description.",
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOUCLIER DE CONFIANCE OLI ───
  Widget _buildTrustShield() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.08), Colors.greenAccent.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text("🛡️", style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text("Protection Oli activée", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          
          const _TrustItem(
            icon: Icons.lock,
            color: Colors.greenAccent,
            title: "Paiement sécurisé",
            desc: "L'argent est conservé par Oli jusqu'à la réception du colis.",
          ),
          const SizedBox(height: 10),
          const _TrustItem(
            icon: Icons.warning_amber,
            color: Colors.orangeAccent,
            title: "Ne sortez jamais d'Oli",
            desc: "Si un acheteur vous demande de payer par PayPal, Western Union ou de discuter sur WhatsApp, c'est probablement une arnaque.",
          ),
          const SizedBox(height: 10),
          const _TrustItem(
            icon: Icons.local_shipping,
            color: Colors.blueAccent,
            title: "Livraison suivie",
            desc: "Utilisez uniquement nos bordereaux pour être couvert en cas de perte.",
          ),
        ],
      ),
    );
  }

  // ─── BOUTON PUBLIER ───
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

  // ────────────────── SOUMISSION ──────────────────

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
    if (!_certifyAuthenticity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Vous devez certifier l'authenticité de votre article"),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (_locationController.text.isEmpty) {
      bool success = await _handleLocationRequest();
      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La localisation est requise pour calculer les frais de livraison")));
        return;
      }
    }
    
    final defaultOption = _shippingOptions.first;

    final ok = await ref.read(productControllerProvider.notifier).uploadProduct(
      name: _name.text.trim(),
      price: _price.text.trim(),
      description: _description.text.trim(),
      deliveryPrice: defaultOption.cost,
      deliveryTime: defaultOption.time,
      expressPrice: null,
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
      ref.refresh(marketProductsProvider); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Article publié avec succès !")));
      Navigator.pop(context);
    }
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS RÉUTILISABLES (PRIVÉS AU FICHIER)
// ══════════════════════════════════════════════════════════

class _HelpItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  const _HelpItem({required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(text: "$title : ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              TextSpan(text: desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _TrustItem({required this.icon, required this.color, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(text: "$title : ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              TextSpan(text: desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ]),
          ),
        ),
      ],
    );
  }
}
