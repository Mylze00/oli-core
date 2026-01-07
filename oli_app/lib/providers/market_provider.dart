import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

// Le modèle de produit
class Product {
  final String id, name, price, seller, condition, description, color, deliveryTime;
  final double deliveryPrice, rating;
  final int quantity, reviews;
  final List<File> images;
  final int totalBuyerRatings;
  
  Product({
    required this.id, required this.name, required this.price,
    required this.seller, required this.condition, required this.description,
    required this.color, required this.deliveryPrice, required this.deliveryTime,
    required this.quantity, required this.rating, required this.reviews,
    required this.totalBuyerRatings, this.images = const [],
  });
}

// La logique du Marché
class MarketNotifier extends StateNotifier<List<Product>> {
  MarketNotifier() : super([
    Product(
      id: '1', name: 'iPhone 15 Pro', price: '1200', seller: 'Jean Dupont',
      condition: 'Neuf', description: 'iPhone 15 Pro 256GB noir...', color: 'Noir',
      deliveryPrice: 10, deliveryTime: '2-3 jours', quantity: 2, rating: 4.8,
      reviews: 45, totalBuyerRatings: 95, images: [],
    ),
    Product(
      id: '2', name: 'MacBook Air M2', price: '950', seller: 'Alice Shop',
      condition: 'Occasion', description: 'MacBook Air M2 2022...', color: 'Argent',
      deliveryPrice: 15, deliveryTime: '3-5 jours', quantity: 1, rating: 4.5,
      reviews: 28, totalBuyerRatings: 62, images: [],
    ),
  ]);
  void addProduct(Product p) => state = [p, ...state];
}

// LE PROVIDER (C'est lui que vos pages cherchent)
final marketProductsProvider = StateNotifierProvider<MarketNotifier, List<Product>>((ref) => MarketNotifier());