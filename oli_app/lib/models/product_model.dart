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
  final bool sellerIsVerified;
  final String sellerAccountType;
  final bool sellerHasCertifiedShop;
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
  final bool isGoodDeal;
  final double? discountPrice; // Replaces promoPrice
  final DateTime? discountStartDate;
  final DateTime? discountEndDate;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.seller,
    required this.sellerId,
    this.sellerAvatar,
    this.sellerOliId,
    this.sellerIsVerified = false,
    this.sellerAccountType = 'ordinaire',
    this.sellerHasCertifiedShop = false,
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
    this.createdAt,
    this.isGoodDeal = false,
    this.discountPrice,
    this.discountStartDate,
    this.discountEndDate,
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
      sellerIsVerified: json['sellerIsVerified'] ?? json['seller_is_verified'] ?? false,
      sellerAccountType: json['sellerAccountType'] ?? json['seller_account_type'] ?? 'ordinaire',
      sellerHasCertifiedShop: json['sellerHasCertifiedShop'] ?? json['seller_has_certified_shop'] ?? false,
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
      isGoodDeal: json['isGoodDeal'] ?? json['is_good_deal'] ?? false,
      // Map backend 'discount_price' to discountPrice
      discountPrice: double.tryParse((json['discountPrice'] ?? json['discount_price'])?.toString() ?? ''),
      discountStartDate: json['discountStartDate'] != null 
          ? DateTime.tryParse(json['discountStartDate']) 
          : (json['discount_start_date'] != null ? DateTime.tryParse(json['discount_start_date']) : null),
      discountEndDate: json['discountEndDate'] != null 
          ? DateTime.tryParse(json['discountEndDate']) 
          : (json['discount_end_date'] != null ? DateTime.tryParse(json['discount_end_date']) : null),
    );
  }

  /// Première image ou null
  String? get imageUrl => images.isNotEmpty ? images.first : null;
}

