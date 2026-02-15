/// Modèle d'une commande
class Order {
  final int id;
  final int userId;
  final String status;
  final double totalAmount;
  final String? deliveryAddress;
  final double deliveryFee;
  final String? paymentMethod;
  final String paymentStatus;
  final String? deliveryCode;
  final String? deliveryMethodId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.userId,
    required this.status,
    required this.totalAmount,
    this.deliveryAddress,
    this.deliveryFee = 0,
    this.paymentMethod,
    required this.paymentStatus,
    this.deliveryCode,
    this.deliveryMethodId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return Order(
      id: json['id'],
      userId: json['user_id'],
      status: json['status'] ?? 'pending',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      deliveryAddress: json['delivery_address'],
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'] ?? 'pending',
      deliveryCode: json['delivery_code'],
      deliveryMethodId: json['delivery_method_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      items: itemsJson.map((e) => OrderItem.fromJson(e)).toList(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'En attente';
      case 'paid': return 'Payée';
      case 'processing': return 'En préparation';
      case 'shipped': return 'Expédiée';
      case 'delivered': return 'Livrée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  bool get canCancel => status == 'pending' || status == 'paid';
}

/// Modèle d'un item de commande
class OrderItem {
  final int? id;
  final String productId;
  final String productName;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String? sellerName;

  OrderItem({
    this.id,
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.price,
    required this.quantity,
    this.sellerName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      productId: json['productId'] ?? json['product_id'] ?? '',
      productName: json['productName'] ?? json['product_name'] ?? '',
      imageUrl: json['imageUrl'] ?? json['product_image_url'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] ?? 1,
      sellerName: json['sellerName'] ?? json['seller_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'imageUrl': imageUrl,
    'price': price,
    'quantity': quantity,
    'sellerName': sellerName,
  };

  double get total => price * quantity;
}
