/// Modèle de variante produit aligné avec la table product_variants
class ProductVariant {
  final String id;
  final int productId;
  final String variantType;   // 'size', 'color', 'material', etc.
  final String variantValue;  // 'XL', 'Rouge', '128GB', etc.
  final double priceAdjustment;
  final int stockQuantity;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.variantType,
    required this.variantValue,
    this.priceAdjustment = 0.0,
    this.stockQuantity = 0,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id']?.toString() ?? '',
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      variantType: json['variant_type'] ?? '',
      variantValue: json['variant_value'] ?? '',
      priceAdjustment: double.tryParse(json['price_adjustment']?.toString() ?? '0') ?? 0.0,
      stockQuantity: int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
    );
  }

  /// Label traduit pour le type de variante
  String get typeLabel {
    switch (variantType) {
      case 'size': return 'Taille';
      case 'color': return 'Couleur';
      case 'material': return 'Matériau';
      case 'capacity': return 'Capacité';
      case 'style': return 'Style';
      case 'packaging': return 'Conditionnement';
      default: return variantType;
    }
  }

  bool get inStock => stockQuantity > 0;
}
