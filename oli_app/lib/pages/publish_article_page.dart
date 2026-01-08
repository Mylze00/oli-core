import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../product_controller.dart';
import '../models/product_model.dart';

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
  final _formKey = GlobalKey<FormState>();

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
      appBar: AppBar(title: const Text("Vendre un article"), backgroundColor: Colors.black),
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
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: kIsWeb 
                                        ? NetworkImage(_images[i].path)
                                        : _getMobileImage(_images[i].path),
                                      fit: BoxFit.cover
                                    )
                                )
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
                          imageFile: _images[0],
                        );
                        if (ok) {
                          ref.read(marketProductsProvider.notifier).addProduct(Product(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _name.text.trim(),
                            price: _price.text.trim(),
                            seller: 'Moi',
                            condition: _condition,
                            description: _description.text.trim(),
                            color: _color.text.trim(),
                            deliveryPrice: double.tryParse(_deliveryPrice.text.trim()) ?? 0,
                            deliveryTime: _deliveryTime.text.trim(),
                            quantity: int.tryParse(_quantity.text.trim()) ?? 1,
                            rating: 5.0,
                            reviews: 0,
                            totalBuyerRatings: 100,
                            images: _images,
                          ));
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
}  }

  ImageProvider _getMobileImage(String path) {
    return NetworkImage(path); 
  }
}
