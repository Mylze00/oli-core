import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';

/// Modèle d'un item dans le panier
class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  final String? imageUrl;
  final String? sellerName;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.sellerName,
  });

  double get total => price * quantity;

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
      // Produit déjà présent, augmenter la quantité
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            CartItem(
              productId: state[i].productId,
              productName: state[i].productName,
              price: state[i].price,
              quantity: state[i].quantity + item.quantity,
              imageUrl: state[i].imageUrl,
              sellerName: state[i].sellerName,
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
          CartItem(
            productId: item.productId,
            productName: item.productName,
            price: item.price,
            quantity: quantity,
            imageUrl: item.imageUrl,
            sellerName: item.sellerName,
          )
        else
          item
    ];
  }

  /// Vider le panier
  void clearCart() {
    state = [];
  }

  /// Nombre total d'articles
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  /// Prix total
  double get totalPrice => state.fold(0, (sum, item) => sum + item.total);

  /// Convertir en liste d'OrderItems pour l'API
  List<OrderItem> toOrderItems() => state.map((e) => e.toOrderItem()).toList();
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

/// Provider du total du panier
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});
