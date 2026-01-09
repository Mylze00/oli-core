class DeliveryOrder {
  final int id;
  final int orderId; // Integer now
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double deliveryFee;
  final String estimatedTime;
  final int? delivererRating;
  final String? customerName;
  final String? customerPhone;

  DeliveryOrder({
    required this.id,
    required this.orderId,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryFee = 0.0,
    this.estimatedTime = '',
    this.delivererRating,
    this.customerName,
    this.customerPhone,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'],
      orderId: json['order_id'],
      status: json['status'],
      pickupAddress: json['pickup_address'],
      deliveryAddress: json['delivery_address'],
      pickupLat: json['pickup_lat'] != null ? double.parse(json['pickup_lat'].toString()) : null,
      pickupLng: json['pickup_lng'] != null ? double.parse(json['pickup_lng'].toString()) : null,
      deliveryLat: json['delivery_lat'] != null ? double.parse(json['delivery_lat'].toString()) : null,
      deliveryLng: json['delivery_lng'] != null ? double.parse(json['delivery_lng'].toString()) : null,
      deliveryFee: json['delivery_fee'] != null ? double.parse(json['delivery_fee'].toString()) : 0.0,
      estimatedTime: json['estimated_time'] ?? '',
      delivererRating: json['deliverer_rating'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
    );
  }
}
