import 'package:flutter/foundation.dart';

/// Modèle pour les filtres de recherche
@immutable
class SearchFilters {
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final bool? verifiedShopsOnly;
  final bool? inStockOnly;
  final String? sellerName;
  final String? location;

  const SearchFilters({
    this.category,
    this.minPrice,
    this.maxPrice,
    this.verifiedShopsOnly,
    this.inStockOnly,
    this.sellerName,
    this.location,
  });

  /// Vérifie si des filtres sont actifs
  bool get hasActiveFilters =>
      category != null ||
      minPrice != null ||
      maxPrice != null ||
      verifiedShopsOnly == true ||
      inStockOnly == true ||
      sellerName != null ||
      location != null;

  /// Compte le nombre de filtres actifs
  int get activeFiltersCount {
    int count = 0;
    if (category != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (verifiedShopsOnly == true) count++;
    if (inStockOnly == true) count++;
    if (sellerName != null) count++;
    if (location != null) count++;
    return count;
  }

  /// Copie avec modifications
  SearchFilters copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? verifiedShopsOnly,
    bool? inStockOnly,
    String? sellerName,
    String? location,
    bool clearCategory = false,
    bool clearPrice = false,
    bool clearShopType = false,
    bool clearStock = false,
    bool clearSeller = false,
    bool clearLocation = false,
  }) {
    return SearchFilters(
      category: clearCategory ? null : (category ?? this.category),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      verifiedShopsOnly: clearShopType ? null : (verifiedShopsOnly ?? this.verifiedShopsOnly),
      inStockOnly: clearStock ? null : (inStockOnly ?? this.inStockOnly),
      sellerName: clearSeller ? null : (sellerName ?? this.sellerName),
      location: clearLocation ? null : (location ?? this.location),
    );
  }

  /// Réinitialise tous les filtres
  SearchFilters reset() {
    return const SearchFilters();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilters &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          verifiedShopsOnly == other.verifiedShopsOnly &&
          inStockOnly == other.inStockOnly &&
          sellerName == other.sellerName &&
          location == other.location;

  @override
  int get hashCode =>
      category.hashCode ^
      minPrice.hashCode ^
      maxPrice.hashCode ^
      verifiedShopsOnly.hashCode ^
      inStockOnly.hashCode ^
      sellerName.hashCode ^
      location.hashCode;
}
