/// Modèle de commande vendeur
class SellerOrder {
  final int id;
  final int userId;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final String? deliveryAddress;
  final double deliveryFee;
  final String? deliveryMethodId;
  final String? pickupCode;
  final String? deliveryCode;
  final String? trackingNumber;
  final String? carrier;
  final DateTime? estimatedDelivery;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? buyerName;
  final String? buyerPhone;
  final List<SellerOrderItem> items;

  SellerOrder({
    required this.id,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    this.deliveryAddress,
    required this.deliveryFee,
    this.deliveryMethodId,
    this.pickupCode,
    this.deliveryCode,
    this.trackingNumber,
    this.carrier,
    this.estimatedDelivery,
    this.shippedAt,
    this.deliveredAt,
    required this.createdAt,
    this.updatedAt,
    this.buyerName,
    this.buyerPhone,
    required this.items,
  });

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    return SellerOrder(
      id: json['id'],
      userId: json['user_id'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'pending',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      deliveryAddress: json['delivery_address'],
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      deliveryMethodId: json['delivery_method_id'],
      pickupCode: json['pickup_code'],
      deliveryCode: json['delivery_code'],
      trackingNumber: json['tracking_number'],
      carrier: json['carrier'],
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.tryParse(json['estimated_delivery'])
          : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.tryParse(json['shipped_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      buyerName: json['buyer_name'],
      buyerPhone: json['buyer_phone'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SellerOrderItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Labels pour les statuts
  static const Map<String, String> statusLabels = {
    'pending': 'En attente',
    'paid': 'Payée',
    'processing': 'En préparation',
    'ready': 'Prête',
    'shipped': 'Expédiée',
    'delivered': 'Livrée',
    'cancelled': 'Annulée',
  };

  String get statusLabel => statusLabels[status] ?? status;

  /// Transitions autorisées pour le vendeur
  /// Seul le passage paid→processing est géré par le vendeur
  /// shipped est géré par le livreur via le pickup_code
  /// delivered est géré par le livreur via le delivery_code
  List<String> get allowedTransitions {
    switch (status) {
      case 'paid':
        return ['processing'];
      default:
        return [];
    }
  }
}

/// Item de commande vendeur
class SellerOrderItem {
  final int? id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final double price;
  final int quantity;
  final String? sellerName;

  SellerOrderItem({
    this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.price,
    required this.quantity,
    this.sellerName,
  });

  factory SellerOrderItem.fromJson(Map<String, dynamic> json) {
    return SellerOrderItem(
      id: json['id'],
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] ?? 'Produit',
      productImageUrl: json['product_image_url'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] ?? 1,
      sellerName: json['seller_name'],
    );
  }
}

/// Statistiques des ventes
class SellerOrderStats {
  final int toProcess;
  final int processing;
  final int shipped;
  final int delivered;
  final int newToday;
  final double deliveredRevenue;

  SellerOrderStats({
    required this.toProcess,
    required this.processing,
    required this.shipped,
    required this.delivered,
    required this.newToday,
    required this.deliveredRevenue,
  });

  factory SellerOrderStats.fromJson(Map<String, dynamic> json) {
    return SellerOrderStats(
      toProcess: int.tryParse(json['to_process']?.toString() ?? '0') ?? 0,
      processing: int.tryParse(json['processing']?.toString() ?? '0') ?? 0,
      shipped: int.tryParse(json['shipped']?.toString() ?? '0') ?? 0,
      delivered: int.tryParse(json['delivered']?.toString() ?? '0') ?? 0,
      newToday: int.tryParse(json['new_today']?.toString() ?? '0') ?? 0,
      deliveredRevenue:
          double.tryParse(json['delivered_revenue']?.toString() ?? '0') ?? 0,
    );
  }

  int get total => toProcess + processing + shipped + delivered;
}
