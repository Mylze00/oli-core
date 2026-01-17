class Address {
  final int id;
  final int userId;
  final String label; // "Maison", "Bureau", "Chez Maman", etc.
  final String address;
  final String city;
  final String phone;
  final bool isDefault;

  Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    required this.city,
    required this.phone,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      userId: json['user_id'],
      label: json['label'] ?? "Adresse",
      address: json['address'] ?? "",
      city: json['city'] ?? "",
      phone: json['phone'] ?? "",
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'address': address,
      'city': city,
      'phone': phone,
      'is_default': isDefault,
    };
  }

  String get fullAddress => "$address, $city";
}
