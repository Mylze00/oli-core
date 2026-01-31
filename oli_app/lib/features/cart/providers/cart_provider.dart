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
  final double deliveryPrice;
  final String deliveryMethod; // "Standard" ou "Express"

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.sellerName,
    this.deliveryPrice = 0.0,
    this.deliveryMethod = 'Standard',
  });

  // Le total prend en compte le prix du produit * quantite + livraison (une fois par article ou par quantité ?)
  // Généralement livraison = une fois par commande vendeur, mais ici simplifions : 
  // Si oli-logistic : souvent par poids/article. Disons par article pour l'instant.
  double get total => (price * quantity) + deliveryPrice; 

  OrderItem toOrderItem() => OrderItem(
    productId: productId,
    productName: productName,
    price: price,
    quantity: quantity,
    imageUrl: imageUrl,
    sellerName: sellerName,
    // Note: OrderItem devra aussi être mis à jour si on veut persister le mode de livraison
  );
}

/// Notifier pour gérer l'état du panier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Ajouter un produit au panier
  void addItem(CartItem item) {
    // On différencie aussi par mode de livraison pour éviter les conflits ? 
    // Non, si on change le mode, on met à jour l'item.
    final existingIndex = state.indexWhere((e) => e.productId == item.productId);
    
    if (existingIndex >= 0) {
      // Produit déjà présent, on remplace (pour mettre à jour le mode de livraison et quantité si besoin)
      // Ou on incrémente juste la quantité ?
      // Si l'utilisateur change le mode de livraison, on doit mettre à jour l'item existant.
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
              deliveryPrice: item.deliveryPrice, // Mise à jour du prix livraison
              deliveryMethod: item.deliveryMethod, // Mise à jour du mode
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
            deliveryPrice: item.deliveryPrice,
            deliveryMethod: item.deliveryMethod,
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
