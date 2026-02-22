import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/providers/market_provider.dart';
import '../providers/product_controller.dart';
import '../../../models/product_model.dart';

class EditProductPage extends ConsumerStatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _color;
  late final TextEditingController _location;

  late String _condition;
  late String _category;

  // Livraison
  late List<ShippingOption> _shippingOptions;

  final List<Map<String, String>> _availableMethods = [
    {'id': 'oli_express', 'label': 'Oli Express', 'time': '1-2h'},
    {'id': 'oli_standard', 'label': 'Oli Standard', 'time': '2-5 jours'},
    {'id': 'partner', 'label': 'Livreur Partenaire', 'time': 'Variable'},
    {'id': 'hand_delivery', 'label': 'Remise en Main Propre', 'time': 'À convenir'},
    {'id': 'pick_go', 'label': 'Pick & Go', 'time': 'Retrait'},
    {'id': 'free', 'label': 'Livraison Gratuite', 'time': '3-7 jours'},
  ];

  final List<Map<String, String>> _categories = [
    {'key': 'industry',     'label': 'Industrie'},
    {'key': 'home',         'label': 'Maison'},
    {'key': 'vehicles',     'label': 'Véhicules'},
    {'key': 'fashion',      'label': 'Mode'},
    {'key': 'electronics',  'label': 'Électronique'},
    {'key': 'sports',       'label': 'Sports'},
    {'key': 'beauty',       'label': 'Beauté'},
    {'key': 'toys',         'label': 'Jouets'},
    {'key': 'health',       'label': 'Santé'},
    {'key': 'construction', 'label': 'Construction'},
    {'key': 'tools',        'label': 'Outils'},
    {'key': 'office',       'label': 'Bureau'},
    {'key': 'garden',       'label': 'Jardin'},
    {'key': 'pets',         'label': 'Animaux'},
    {'key': 'baby',         'label': 'Bébé'},
    {'key': 'food',         'label': 'Alimentation'},
    {'key': 'security',     'label': 'Sécurité'},
    {'key': 'other',        'label': 'Autres'},
  ];

  final List<String> _conditions = ['Neuf', 'Occasion', 'Fonctionnel', 'Pour pièce ou à réparer'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _name = TextEditingController(text: p.name);
    _price = TextEditingController(text: p.price);
    _description = TextEditingController(text: p.description);
    _quantity = TextEditingController(text: p.quantity.toString());
    _color = TextEditingController(text: p.color);
    _location = TextEditingController(text: p.location ?? '');

    _condition = _conditions.contains(p.condition) ? p.condition : 'Neuf';
    // Resolve category: support both EN keys and old FR labels
    final labelToKey = <String, String>{};
    for (final c in _categories) {
      labelToKey[c['label']!] = c['key']!;
    }
    final validKeys = _categories.map((c) => c['key']).toSet();
    final rawCat = p.category ?? 'other';
    if (validKeys.contains(rawCat)) {
      _category = rawCat;
    } else if (labelToKey.containsKey(rawCat)) {
      _category = labelToKey[rawCat]!;
    } else {
      _category = 'other';
    }

    // Copier les shipping options existantes
    _shippingOptions = p.shippingOptions.isNotEmpty
        ? List.from(p.shippingOptions)
        : [ShippingOption(methodId: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', cost: 0.0)];
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _quantity.dispose();
    _color.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(productControllerProvider.notifier).updateProduct(
      productId: widget.product.id,
      name: _name.text.trim(),
      price: _price.text.trim(),
      description: _description.text.trim(),
      condition: _condition,
      quantity: int.tryParse(_quantity.text) ?? 1,
      color: _color.text.trim(),
      category: _category,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      shippingOptions: _shippingOptions,
    );

    if (ok && mounted) {
      ref.read(marketProductsProvider.notifier).fetchProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Annonce modifiée avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // true = something changed
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);
    final isLoading = state is AsyncLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Modifier l'annonce", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ─── IMAGES (lecture seule) ───
            _buildExistingImages(),
            const SizedBox(height: 20),

            // ─── CHAMPS PRINCIPAUX ───
            _buildTextField(_name, "Nom du produit", Icons.shopping_bag),
            _buildTextField(_price, "Prix de vente (\$)", Icons.attach_money, isNumber: true),
            _buildCategoryDropdown(),
            const SizedBox(height: 15),
            _buildConditionDropdown(),

            // ─── LIVRAISON ───
            const SizedBox(height: 20),
            const Text("Options de livraison", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDeliveryOptions(),

            // ─── DÉTAILS ───
            const SizedBox(height: 20),
            _buildTextField(_description, "Description détaillée", Icons.description, maxLines: 3),
            _buildTextField(_quantity, "Quantité en stock", Icons.inventory, isNumber: true),
            _buildTextField(_color, "Couleur(s)", Icons.palette),
            _buildTextField(_location, "Localisation", Icons.location_on),

            // ─── BOUTON ENREGISTRER ───
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Enregistrer les modifications", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════

  Widget _buildExistingImages() {
    final images = widget.product.images;
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Photos actuelles", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text("(${images.length})", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Non modifiable",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (ctx, i) {
              final url = images[i].startsWith('http') ? images[i] : 'https://oli-api.onrender.com${images[i]}';
              return Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                  image: DecorationImage(
                    image: NetworkImage(url),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
      items: _conditions.map((v) {
        return DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white)));
      }).toList(),
      onChanged: (v) => setState(() => _condition = v!),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _categories.any((c) => c['key'] == _category) ? _category : 'other',
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
      items: _categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat['key'],
          child: Text(cat['label']!, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _category = v!),
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
              border: Border.all(color: Colors.white24),
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
                      ),
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Délai",
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
}
