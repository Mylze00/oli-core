import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Product {
  final String id, name, price, seller, condition, description, color, deliveryTime;
  final double deliveryPrice, rating;
  final int quantity, reviews, totalBuyerRatings;
  final List<XFile> images;

  Product({
    required this.id, required this.name, required this.price,
    required this.seller, required this.condition, required this.description,
    required this.color, required this.deliveryPrice, required this.deliveryTime,
    required this.quantity, required this.rating, required this.reviews,
    required this.totalBuyerRatings, this.images = const [],
  });
}

// Le Provider qui contient la liste des produits
class MarketNotifier extends StateNotifier<List<Product>> {
  MarketNotifier() : super([
    Product(
      id: '1', name: 'iPhone 15 Pro', price: '1200', seller: 'Jean Dupont',
      condition: 'Neuf', description: 'iPhone 15 Pro 256GB noir...',
      color: 'Noir', deliveryPrice: 10, deliveryTime: '2-3 jours',
      quantity: 2, rating: 4.8, reviews: 45, totalBuyerRatings: 95,
    ),
    // Ajoutez vos autres produits du backup ici
  ]);
}

final marketProductsProvider = StateNotifierProvider<MarketNotifier, List<Product>>((ref) => MarketNotifier());