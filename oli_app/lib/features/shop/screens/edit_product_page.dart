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
  late final TextEditingController _location;

  late String _condition;
  late String _category;

  // Livraison
  late List<ShippingOption> _shippingOptions;

  // Variantes couleurs et tailles
  final List<String> _colors = [];
  final List<String> _sizes  = [];
  final _colorInputCtrl = TextEditingController();
  final _sizeInputCtrl  = TextEditingController();

  static const List<Map<String, String>> _availableMethods = [
    {'id': 'oli_express',    'label': 'Oli Express',            'time': '1-2h'},
    {'id': 'oli_standard',   'label': 'Oli Standard',           'time': '2-5 jours'},
    {'id': 'partner',        'label': 'Livreur Partenaire',     'time': 'Variable'},
    {'id': 'hand_delivery',  'label': 'Remise en Main Propre',  'time': 'À convenir'},
    {'id': 'pick_go',        'label': 'Pick & Go',              'time': 'Retrait'},
    {'id': 'free',           'label': 'Livraison Gratuite',     'time': '3-7 jours'},
  ];

  static const List<Map<String, String>> _categories = [
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

  static const List<String> _conditions = ['Neuf', 'Occasion', 'Fonctionnel', 'Pour pièce ou à réparer'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _name        = TextEditingController(text: p.name);
    _price       = TextEditingController(text: p.price);
    _description = TextEditingController(text: p.description);
    _quantity    = TextEditingController(text: p.quantity.toString());
    _location    = TextEditingController(text: p.location ?? '');

    _condition = _conditions.contains(p.condition) ? p.condition : 'Neuf';

    // Résolution catégorie (clé EN ou label FR)
    final labelToKey = <String, String>{};
    for (final c in _categories) { labelToKey[c['label']!] = c['key']!; }
    final validKeys = _categories.map((c) => c['key']).toSet();
    final rawCat = p.category ?? 'other';
    _category = validKeys.contains(rawCat) ? rawCat : (labelToKey[rawCat] ?? 'other');

    // Options livraison
    _shippingOptions = p.shippingOptions.isNotEmpty
        ? List.from(p.shippingOptions)
        : [ShippingOption(methodId: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', cost: 0.0)];

    // Variantes initiales depuis le champ color
    if (p.color.isNotEmpty) {
      _colors.addAll(p.color.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
  }

  @override
  void dispose() {
    _name.dispose(); _price.dispose(); _description.dispose();
    _quantity.dispose(); _location.dispose();
    _colorInputCtrl.dispose(); _sizeInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(productControllerProvider.notifier).updateProduct(
      productId:       widget.product.id,
      name:            _name.text.trim(),
      price:           _price.text.trim(),
      description:     _description.text.trim(),
      condition:       _condition,
      quantity:        int.tryParse(_quantity.text) ?? 1,
      color:           _colors.join(', '),
      category:        _category,
      location:        _location.text.trim().isEmpty ? null : _location.text.trim(),
      shippingOptions: _shippingOptions,
    );

    if (ok && mounted) {
      ref.read(marketProductsProvider.notifier).fetchProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annonce modifiée avec succès !"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  // ─── Helpers UI ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: child,
  );

  InputDecoration _inputDecor(String label, {IconData? icon, String? hint}) => InputDecoration(
    prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 19) : null,
    labelText: label,
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Widget _buildTextField(TextEditingController ctrl, String label, {IconData? icon, bool isNumber = false, int maxLines = 1, String? hint, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNumber && maxLines == 1 ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : [],
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: required ? (v) => (v == null || v.isEmpty) ? "Champ requis" : null : null,
        decoration: _inputDecor(label, icon: icon, hint: hint),
      ),
    );
  }

  Widget _buildDropdown<T>({required T value, required String label, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: const Color(0xFF1E1E1E),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        icon: const Icon(Icons.expand_more, color: Colors.white38),
        decoration: _inputDecor(label, icon: icon),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  // ─── Section Variantes ────────────────────────────────────────────────────

  void _addChip(List<String> list, TextEditingController ctrl) {
    final val = ctrl.text.trim();
    if (val.isNotEmpty && !list.contains(val)) setState(() => list.add(val));
    ctrl.clear();
  }

  Widget _buildChipSection({
    required String title,
    required String hint,
    required TextEditingController ctrl,
    required List<String> chips,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true, fillColor: Colors.white.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color.withOpacity(0.7))),
            ),
            onSubmitted: (_) => _addChip(chips, ctrl),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _addChip(chips, ctrl),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(Icons.add, color: color, size: 20),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      chips.isEmpty
          ? Text("Aucune variante — tape et appuie + pour ajouter", style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic))
          : Wrap(
              spacing: 7, runSpacing: 6,
              children: chips.map((c) => Chip(
                label: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: color.withOpacity(0.18),
                side: BorderSide(color: color.withOpacity(0.4)),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                onDeleted: () => setState(() => chips.remove(c)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 2),
              )).toList(),
            ),
    ]);
  }

  // ─── Livraison ────────────────────────────────────────────────────────────

  Widget _buildDeliveryOptions() => Column(children: [
    ..._shippingOptions.asMap().entries.map((entry) {
      final idx    = entry.key;
      final option = entry.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
              child: Text("Option ${idx + 1}", style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (_shippingOptions.length > 1)
              IconButton(
                onPressed: () => setState(() => _shippingOptions.removeAt(idx)),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _availableMethods.any((m) => m['id'] == option.methodId) ? option.methodId : 'oli_standard',
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            icon: const Icon(Icons.expand_more, color: Colors.white38),
            decoration: InputDecoration(
              labelText: "Mode de transport",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              prefixIcon: const Icon(Icons.local_shipping_outlined, color: Colors.white38, size: 18),
              filled: true, fillColor: Colors.black12,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
            ),
            items: _availableMethods.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['label']!, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) {
              if (val == null) return;
              final sel = _availableMethods.firstWhere((m) => m['id'] == val);
              setState(() => _shippingOptions[idx] = ShippingOption(
                methodId: val, label: sel['label']!, time: sel['time']!,
                cost: ['free', 'hand_delivery', 'pick_go'].contains(val) ? 0.0 : option.cost,
              ));
            },
          ),
          if (!['free', 'hand_delivery', 'pick_go'].contains(option.methodId)) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: option.cost > 0 ? option.cost.toString() : '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(labelText: "Coût (\$)", labelStyle: const TextStyle(color: Colors.white38, fontSize: 12), filled: true, fillColor: Colors.black12, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent))),
                onChanged: (val) => setState(() => _shippingOptions[idx] = ShippingOption(methodId: option.methodId, label: option.label, time: option.time, cost: double.tryParse(val) ?? 0.0)),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                initialValue: option.time,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(labelText: "Délai", labelStyle: const TextStyle(color: Colors.white38, fontSize: 12), filled: true, fillColor: Colors.black12, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent))),
                onChanged: (val) => setState(() => _shippingOptions[idx] = ShippingOption(methodId: option.methodId, label: option.label, time: val, cost: option.cost)),
              )),
            ]),
          ],
        ]),
      );
    }),
    TextButton.icon(
      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
      label: const Text("Ajouter un mode de livraison", style: TextStyle(color: Colors.blueAccent)),
      onPressed: () => setState(() => _shippingOptions.add(ShippingOption(methodId: 'oli_standard', label: 'Oli Standard', time: '2-5 jours', cost: 0.0))),
    ),
  ]);

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(productControllerProvider);
    final isLoading = state is AsyncLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text("Modifier l'annonce", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: Colors.white10)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 40),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // PHOTOS
            _card(child: _buildExistingImages()),

            // INFOS PRODUIT
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Informations produit", Icons.inventory_2_outlined, Colors.blueAccent),
              _buildTextField(_name, "Nom du produit", icon: Icons.shopping_bag_outlined, hint: "Ex: Veste en cuir marron taille L"),
              _buildTextField(_price, "Prix de vente (\$)", icon: Icons.attach_money, isNumber: true),
              _buildDropdown<String>(
                value: _categories.any((c) => c['key'] == _category) ? _category : 'other',
                label: "Catégorie", icon: Icons.category_outlined,
                items: _categories.map((cat) => DropdownMenuItem(value: cat['key'], child: Text(cat['label']!, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              _buildDropdown<String>(
                value: _condition, label: "État du produit", icon: Icons.star_outline,
                items: _conditions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => _condition = v!),
              ),
            ])),

            // STOCK
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Stock & Localisation", Icons.warehouse_outlined, Colors.orangeAccent),
              _buildTextField(_quantity, "Quantité en stock", icon: Icons.inventory, isNumber: true),
              _buildTextField(_location, "Localisation", icon: Icons.location_on_outlined, required: false, hint: "Ex: Kinshasa, Gombe"),
            ])),

            // VARIANTES
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Variantes produit", Icons.palette_outlined, Colors.purpleAccent),
              _buildChipSection(title: "Couleurs", hint: "Ex: Rouge, Bleu...", ctrl: _colorInputCtrl, chips: _colors, color: Colors.purpleAccent),
              const SizedBox(height: 16),
              _buildChipSection(title: "Tailles", hint: "Ex: S, M, L, XL ou 38, 40...", ctrl: _sizeInputCtrl, chips: _sizes, color: Colors.tealAccent),
            ])),

            // DESCRIPTION
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Description", Icons.description_outlined, Colors.greenAccent),
              _buildTextField(_description, "Description détaillée", icon: Icons.notes, maxLines: 4, required: false, hint: "Caractéristiques, matière, dimensions..."),
            ])),

            // LIVRAISON
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader("Options de livraison", Icons.local_shipping_outlined, Colors.amberAccent),
              _buildDeliveryOptions(),
            ])),

            // BOUTON
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _submitEdit,
                icon: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: const Text("Enregistrer les modifications", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blueAccent.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildExistingImages() {
    final images = widget.product.images;
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text("Photos actuelles", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text("(${images.length})", style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 10, color: Colors.amber),
            SizedBox(width: 4),
            Text("Non modifiable", style: TextStyle(color: Colors.amber, fontSize: 10)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          itemBuilder: (ctx, i) {
            final url = images[i].startsWith('http') ? images[i] : 'https://oli-api.onrender.com${images[i]}';
            return Container(
              width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
                image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
