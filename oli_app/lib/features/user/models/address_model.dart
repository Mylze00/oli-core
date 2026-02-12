class Address {
  final int id;
  final int userId;
  final String label; // "Maison", "Bureau", "Chez Maman", etc.
  final String address;
  final String city;
  final String phone;
  final bool isDefault;
  // Champs structurés
  final String? avenue;
  final String? numero;
  final String? quartier;
  final String? commune;
  final String? ville;
  final String? province;
  final String? referencePoint;
  final double? latitude;
  final double? longitude;

  Address({
    this.id = 0,
    this.userId = 0,
    this.label = 'Maison',
    this.address = '',
    this.city = '',
    this.phone = '',
    this.isDefault = false,
    this.avenue,
    this.numero,
    this.quartier,
    this.commune,
    this.ville,
    this.province,
    this.referencePoint,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      label: json['label'] ?? "Adresse",
      address: json['address'] ?? "",
      city: json['city'] ?? "",
      phone: json['phone'] ?? "",
      isDefault: json['is_default'] ?? false,
      avenue: json['avenue'],
      numero: json['numero'],
      quartier: json['quartier'],
      commune: json['commune'],
      ville: json['ville'] ?? 'Kinshasa',
      province: json['province'],
      referencePoint: json['reference_point'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'address': address,
      'city': city,
      'phone': phone,
      'is_default': isDefault,
      'avenue': avenue,
      'numero': numero,
      'quartier': quartier,
      'commune': commune,
      'ville': ville ?? 'Kinshasa',
      'province': province,
      'reference_point': referencePoint,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Adresse complète lisible
  String get fullAddress {
    final parts = <String>[];
    if (avenue != null && avenue!.isNotEmpty) {
      parts.add(numero != null && numero!.isNotEmpty ? '$avenue N°$numero' : avenue!);
    }
    if (quartier != null && quartier!.isNotEmpty) parts.add('Q/$quartier');
    if (commune != null && commune!.isNotEmpty) parts.add('C/$commune');
    if (ville != null && ville!.isNotEmpty) parts.add(ville!);
    if (parts.isEmpty && address.isNotEmpty) return address;
    return parts.join(', ');
  }

  /// Résumé court (quartier/commune)
  String get shortAddress {
    final parts = <String>[];
    if (quartier != null && quartier!.isNotEmpty) parts.add(quartier!);
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    return parts.isNotEmpty ? parts.join(', ') : address;
  }

  /// Vérifie si l'adresse a des coordonnées GPS
  bool get hasCoordinates => latitude != null && longitude != null;

  Address copyWith({
    int? id,
    int? userId,
    String? label,
    String? address,
    String? city,
    String? phone,
    bool? isDefault,
    String? avenue,
    String? numero,
    String? quartier,
    String? commune,
    String? ville,
    String? province,
    String? referencePoint,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
      avenue: avenue ?? this.avenue,
      numero: numero ?? this.numero,
      quartier: quartier ?? this.quartier,
      commune: commune ?? this.commune,
      ville: ville ?? this.ville,
      province: province ?? this.province,
      referencePoint: referencePoint ?? this.referencePoint,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
