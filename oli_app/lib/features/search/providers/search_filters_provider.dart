import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_filter_model.dart';

/// Provider pour gérer les filtres de recherche
class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier() : super(const SearchFilters());

  /// Définir la catégorie
  void setCategory(String? category) {
    state = state.copyWith(category: category);
  }

  /// Définir la plage de prix
  void setPriceRange(double? min, double? max) {
    state = state.copyWith(minPrice: min, maxPrice: max);
  }

  /// Définir le type de boutique
  void setVerifiedShopsOnly(bool? value) {
    state = state.copyWith(verifiedShopsOnly: value);
  }

  /// Définir le filtre de disponibilité
  void setInStockOnly(bool? value) {
    state = state.copyWith(inStockOnly: value);
  }

  /// Définir le filtre vendeur
  void setSellerName(String? name) {
    state = state.copyWith(sellerName: name);
  }

  /// Définir le filtre localisation
  void setLocation(String? location) {
    state = state.copyWith(location: location);
  }

  /// Effacer la catégorie
  void clearCategory() {
    state = state.copyWith(clearCategory: true);
  }

  /// Effacer le filtre prix
  void clearPrice() {
    state = state.copyWith(clearPrice: true);
  }

  /// Effacer le filtre boutique
  void clearShopType() {
    state = state.copyWith(clearShopType: true);
  }

  /// Effacer le filtre stock
  void clearStock() {
    state = state.copyWith(clearStock: true);
  }

  /// Effacer le filtre vendeur
  void clearSellerName() {
    state = state.copyWith(clearSeller: true);
  }

  /// Effacer le filtre localisation
  void clearLocation() {
    state = state.copyWith(clearLocation: true);
  }

  /// Réinitialiser tous les filtres
  void reset() {
    state = const SearchFilters();
  }
}

/// Provider Riverpod
final searchFiltersProvider = StateNotifierProvider<SearchFiltersNotifier, SearchFilters>((ref) {
  return SearchFiltersNotifier();
});
