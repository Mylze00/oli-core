import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/order_model.dart';

/// Modèle d'un item dans le panier
class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  final String? imageUrl;
  final String? sellerName;
  final String sellerId;
  final double deliveryPrice;
  final String deliveryMethod;
  final bool isSelected;
  final bool isCertified; // Vendeur/boutique certifié

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
    this.isSelected = true,
    this.isCertified = false,
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
    bool? isCertified,
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
      isCertified: isCertified ?? this.isCertified,
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

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'price': price,
    'quantity': quantity,
    'imageUrl': imageUrl,
    'sellerName': sellerName,
    'sellerId': sellerId,
    'deliveryPrice': deliveryPrice,
    'deliveryMethod': deliveryMethod,
    'isSelected': isSelected,
    'isCertified': isCertified,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['productId'] ?? '',
    productName: json['productName'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 1,
    imageUrl: json['imageUrl'],
    sellerName: json['sellerName'],
    sellerId: json['sellerId'] ?? '',
    deliveryPrice: (json['deliveryPrice'] ?? 0).toDouble(),
    deliveryMethod: json['deliveryMethod'] ?? 'Standard',
    isSelected: json['isSelected'] ?? true,
    isCertified: json['isCertified'] ?? false,
  );
}

/// Notifier pour gérer l'état du panier avec persistance locale
class CartNotifier extends StateNotifier<List<CartItem>> {
  static const _storageKey = 'oli_cart_items';
  static const _deliveryChoicesKey = 'oli_delivery_choices';

  /// Per-seller delivery choice: sellerId → 'pick_go' | 'paid_delivery'
  Map<String, String> _deliveryChoices = {};

  CartNotifier() : super([]) {
    _loadFromStorage();
  }

  Map<String, String> get deliveryChoices => _deliveryChoices;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        state = jsonList.map((e) => CartItem.fromJson(e)).toList();
        debugPrint('🛒 Panier restauré: ${state.length} items');
      }
      // Load delivery choices
      final choicesJson = prefs.getString(_deliveryChoicesKey);
      if (choicesJson != null) {
        _deliveryChoices = Map<String, String>.from(jsonDecode(choicesJson));
      }
    } catch (e) {
      debugPrint('⚠️ Erreur restauration panier: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
      await prefs.setString(_deliveryChoicesKey, jsonEncode(_deliveryChoices));
    } catch (e) {
      debugPrint('⚠️ Erreur sauvegarde panier: $e');
    }
  }

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
    // Default delivery choice for new sellers
    if (!_deliveryChoices.containsKey(item.sellerId)) {
      _deliveryChoices[item.sellerId] = item.isCertified ? 'pick_go' : 'paid_delivery';
    }
    _saveToStorage();
  }

  void removeItem(String productId) {
    state = state.where((item) => item.productId != productId).toList();
    _saveToStorage();
  }

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
    _saveToStorage();
  }

  void toggleItemSelection(String productId) {
    state = [
      for (final item in state)
        if (item.productId == productId)
          item.copyWith(isSelected: !item.isSelected)
        else
          item
    ];
    _saveToStorage();
  }

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
    _saveToStorage();
  }

  void toggleAllSelection() {
    final allSelected = state.every((item) => item.isSelected);
    state = [
      for (final item in state) item.copyWith(isSelected: !allSelected)
    ];
    _saveToStorage();
  }

  /// Set delivery choice per seller
  void setSellerDeliveryChoice(String sellerId, String choice) {
    _deliveryChoices[sellerId] = choice;

    // Update delivery price for all items of this seller
    final double fee = choice == 'pick_go' ? 0.0 : 5.0;
    final String method = choice == 'pick_go' ? 'Pick & Go' : 'Livraison Payante';

    state = [
      for (final item in state)
        if (item.sellerId == sellerId)
          item.copyWith(deliveryPrice: fee, deliveryMethod: method)
        else
          item
    ];
    _saveToStorage();
  }

  String getSellerDeliveryChoice(String sellerId) {
    return _deliveryChoices[sellerId] ?? 'paid_delivery';
  }

  void clearCart() {
    state = [];
    _deliveryChoices = {};
    _saveToStorage();
  }

  Map<String, List<CartItem>> getGroupedCart() {
    return groupBy(state, (CartItem item) => item.sellerId);
  }

  double getShopSubtotal(String sellerId) {
    return state
        .where((item) => item.sellerId == sellerId && item.isSelected)
        .fold(0, (sum, item) => sum + item.total);
  }

  double getShopDeliveryFee(String sellerId) {
    final choice = getSellerDeliveryChoice(sellerId);
    return choice == 'pick_go' ? 0.0 : 5.0;
  }

  List<CartItem> get selectedItems => state.where((item) => item.isSelected).toList();
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => state.fold(0, (sum, item) => sum + item.total);

  double get selectedTotalPrice => state
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.total);

  List<OrderItem> toOrderItems() => selectedItems.map((e) => e.toOrderItem()).toList();
}

/// Provider du panier
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});

final selectedCartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.total);
});

final hasSelectedItemsProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.any((item) => item.isSelected);
});

final groupedCartProvider = Provider<Map<String, List<CartItem>>>((ref) {
  final cart = ref.watch(cartProvider);
  return groupBy(cart, (CartItem item) => item.sellerId);
});
