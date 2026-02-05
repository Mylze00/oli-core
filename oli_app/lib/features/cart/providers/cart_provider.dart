import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../models/order_model.dart';

/// Modèle d'un item dans le panier
class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  final String? imageUrl;
  final String? sellerName;
  final String sellerId; // ID du vendeur/boutique
  final double deliveryPrice;
  final String deliveryMethod; // "Standard" ou "Express"
  final bool isSelected; // État de sélection

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.sellerName,
    required this.sellerId,
    this.deliveryPrice = 0.0,
    this.deliveryMethod = 'Standard',
    this.isSelected = true, // Sélectionné par défaut lors de l'ajout
  });

  double get total => (price * quantity) + deliveryPrice;

  CartItem copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    String? imageUrl,
    String? sellerName,
    String? sellerId,
    double? deliveryPrice,
    String? deliveryMethod,
    bool? isSelected,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerName: sellerName ?? this.sellerName,
      sellerId: sellerId ?? this.sellerId,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  OrderItem toOrderItem() => OrderItem(
    productId: productId,
    productName: productName,
    price: price,
    quantity: quantity,
    imageUrl: imageUrl,
    sellerName: sellerName,
  );
}

/// Notifier pour gérer l'état du panier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Ajouter un produit au panier
  void addItem(CartItem item) {
    final existingIndex = state.indexWhere((e) => e.productId == item.productId);
    
    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            state[i].copyWith(
              quantity: state[i].quantity + item.quantity,
              deliveryPrice: item.deliveryPrice,
              deliveryMethod: item.deliveryMethod,
            )
          else
            state[i]
      ];
    } else {
      state = [...state, item];
    }
  }

  /// Retirer un produit du panier
  void removeItem(String productId) {
    state = state.where((item) => item.productId != productId).toList();
  }

  /// Modifier la quantité
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    
    state = [
      for (final item in state)
        if (item.productId == productId)
          item.copyWith(quantity: quantity)
        else
          item
    ];
  }

  /// Sélectionner/désélectionner un produit
  void toggleItemSelection(String productId) {
    state = [
      for (final item in state)
        if (item.productId == productId)
          item.copyWith(isSelected: !item.isSelected)
        else
          item
    ];
  }

  /// Sélectionner/désélectionner tous les produits d'une boutique
  void toggleShopSelection(String sellerId) {
    final shopItems = state.where((item) => item.sellerId == sellerId).toList();
    final allSelected = shopItems.every((item) => item.isSelected);
    
    state = [
      for (final item in state)
        if (item.sellerId == sellerId)
          item.copyWith(isSelected: !allSelected)
        else
          item
    ];
  }

  /// Tout sélectionner/désélectionner
  void toggleAllSelection() {
    final allSelected = state.every((item) => item.isSelected);
    
    state = [
      for (final item in state)
        item.copyWith(isSelected: !allSelected)
    ];
  }

  /// Vider le panier
  void clearCart() {
    state = [];
  }

  /// Grouper les items par vendeur
  Map<String, List<CartItem>> getGroupedCart() {
    return groupBy(state, (CartItem item) => item.sellerId);
  }

  /// Calculer le sous-total d'une boutique (produits sélectionnés uniquement)
  double getShopSubtotal(String sellerId) {
    return state
        .where((item) => item.sellerId == sellerId && item.isSelected)
        .fold(0, (sum, item) => sum + item.total);
  }

  /// Items sélectionnés uniquement
  List<CartItem> get selectedItems => state.where((item) => item.isSelected).toList();

  /// Nombre total d'articles
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  /// Prix total (tous les items)
  double get totalPrice => state.fold(0, (sum, item) => sum + item.total);

  /// Prix total des items sélectionnés
  double get selectedTotalPrice => state
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.total);

  /// Convertir les items sélectionnés en liste d'OrderItems pour l'API
  List<OrderItem> toOrderItems() => selectedItems.map((e) => e.toOrderItem()).toList();
}

/// Provider du panier
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Provider du nombre d'items dans le panier (pour badge)
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Provider du total du panier (tous les items)
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});

/// Provider du total des items sélectionnés
final selectedCartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.total);
});

/// Provider pour vérifier si au moins un item est sélectionné
final hasSelectedItemsProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.any((item) => item.isSelected);
});

/// Provider du panier groupé par vendeur
final groupedCartProvider = Provider<Map<String, List<CartItem>>>((ref) {
  final cart = ref.watch(cartProvider);
  return groupBy(cart, (CartItem item) => item.sellerId);
});
