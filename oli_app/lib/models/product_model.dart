import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class Product {
  final String id, name, price, seller, sellerId, condition, description, color, deliveryTime;
  final double deliveryPrice, rating;
  final int quantity, reviews, totalBuyerRatings;
  final List<String> images; 

  Product({
    required this.id, required this.name, required this.price,
    required this.seller, required this.sellerId, required this.condition, 
    required this.description, required this.color, required this.deliveryPrice, 
    required this.deliveryTime, required this.quantity, required this.rating, 
    required this.reviews, required this.totalBuyerRatings, this.images = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> imagesList = [];
    if (json['images'] != null) {
      imagesList = List<String>.from(json['images']);
    } else if (json['imageUrl'] != null) {
      imagesList = [json['imageUrl'] as String];
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Produit sans nom',
      price: json['price']?.toString() ?? '0',
      seller: json['sellerName'] ?? 'Anonyme',
      sellerId: json['sellerId']?.toString() ?? '',
      condition: json['condition'] ?? 'Inconnu',
      description: json['description'] ?? '',
      color: json['color'] ?? '',
      deliveryPrice: double.tryParse(json['delivery_price']?.toString() ?? '0') ?? 0.0,
      deliveryTime: json['delivery_time'] ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      rating: 5.0,
      reviews: 0,
      totalBuyerRatings: 100,
      images: imagesList,
    );
  }
}

class MarketNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;

  MarketNotifier() : super([]) {
    fetchProducts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => fetchProducts());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.products));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (newProducts.isNotEmpty) {
          final p = newProducts.first;
          debugPrint("[DIAG] ${newProducts.length} produits charges. Premier ID: ${p.id} | SellerID: ${p.sellerId}");
        }

        state = newProducts;
      }
    } catch (e) {
      debugPrint("Erreur fetchProducts: $e");
    }
  }

  void addProduct(Product product) {
    state = [product, ...state];
  }
}

final marketProductsProvider = StateNotifierProvider<MarketNotifier, List<Product>>((ref) => MarketNotifier());