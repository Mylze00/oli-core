import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Modèle Product aligné avec l'API Backend Oli
class Product {
  final String id;
  final String name;
  final String price;
  final String seller;
  final String sellerId;
  final String? sellerAvatar;
  final String? sellerOliId;
  final String condition;
  final String description;
  final String color;
  final String deliveryTime;
  final double deliveryPrice;
  final double rating;
  final int quantity;
  final int reviews;
  final int totalBuyerRatings;
  final String? location;
  final bool isNegotiable;
  final String? shopId;
  final String? shopName;
  final bool shopVerified;
  final List<String> images;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.seller,
    required this.sellerId,
    this.sellerAvatar,
    this.sellerOliId,
    required this.condition,
    required this.description,
    required this.color,
    required this.deliveryPrice,
    required this.deliveryTime,
    required this.quantity,
    required this.rating,
    required this.reviews,
    required this.totalBuyerRatings,
    this.location,
    this.isNegotiable = false,
    this.shopId,
    this.shopName,
    this.shopVerified = false,
    this.images = const [],
    this.createdAt,
  });

  /// Factory pour parser la réponse API (supporte camelCase ET snake_case)
  factory Product.fromJson(Map<String, dynamic> json) {
    // Gestion des images (peut être un array ou une string)
    List<String> imagesList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imagesList = List<String>.from(json['images']);
      } else if (json['images'] is String) {
        imagesList = (json['images'] as String)
            .replaceAll(RegExp(r'[{}""]'), '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } else if (json['imageUrl'] != null) {
      imagesList = [json['imageUrl'] as String];
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Produit sans nom',
      price: json['price']?.toString() ?? '0',
      seller: json['sellerName'] ?? json['seller_name'] ?? 'Anonyme',
      sellerId: json['sellerId']?.toString() ?? json['seller_id']?.toString() ?? '',
      sellerAvatar: json['sellerAvatar'] ?? json['seller_avatar'],
      sellerOliId: json['sellerOliId'] ?? json['seller_oli_id'],
      condition: json['condition'] ?? 'Inconnu',
      description: json['description'] ?? '',
      color: json['color'] ?? '',
      // Support camelCase ET snake_case
      deliveryPrice: double.tryParse(
        (json['deliveryPrice'] ?? json['delivery_price'])?.toString() ?? '0'
      ) ?? 0.0,
      deliveryTime: json['deliveryTime'] ?? json['delivery_time'] ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      rating: 5.0, // TODO: implémenter les avis
      reviews: 0,
      totalBuyerRatings: 100,
      location: json['location'],
      isNegotiable: json['isNegotiable'] ?? json['is_negotiable'] ?? false,
      shopId: json['shopId']?.toString() ?? json['shop_id']?.toString(),
      shopName: json['shopName'] ?? json['shop_name'],
      shopVerified: json['shopVerified'] ?? json['shop_verified'] ?? false,
      images: imagesList,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null),
    );
  }

  /// Première image ou null
  String? get imageUrl => images.isNotEmpty ? images.first : null;
}

/// Notifier pour la liste des produits du marketplace
class MarketNotifier extends StateNotifier<List<Product>> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _error;

  MarketNotifier() : super([]) {
    fetchProducts();
    // Rafraîchissement automatique toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => fetchProducts());
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Récupère les produits depuis l'API
  Future<void> fetchProducts({
    String? category,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? location,
  }) async {
    _isLoading = true;
    _error = null;

    try {
      // Construire l'URL avec les filtres
      final uri = Uri.parse(ApiConfig.products).replace(queryParameters: {
        if (category != null) 'category': category,
        if (search != null) 'search': search,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
        if (location != null) 'location': location,
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newProducts = data.map((item) => Product.fromJson(item)).toList();
        
        if (newProducts.isNotEmpty) {
          final p = newProducts.first;
          debugPrint("✅ ${newProducts.length} produits chargés. Premier: ${p.name} (ID: ${p.id})");
        }

        state = newProducts;
        _error = null;
      } else {
        _error = "Erreur serveur: ${response.statusCode}";
        debugPrint("❌ Erreur fetchProducts: ${response.statusCode}");
      }
    } catch (e) {
      _error = "Erreur réseau: $e";
      debugPrint("❌ Exception fetchProducts: $e");
    } finally {
      _isLoading = false;
    }
  }

  /// Ajoute un produit localement (après publication réussie)
  void addProduct(Product product) {
    state = [product, ...state];
  }

  /// Supprime un produit localement
  void removeProduct(String productId) {
    state = state.where((p) => p.id != productId).toList();
  }
}

/// Provider global pour les produits du marketplace
final marketProductsProvider = StateNotifierProvider<MarketNotifier, List<Product>>((ref) => MarketNotifier());