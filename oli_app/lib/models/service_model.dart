class ServiceModel {
  final int id;
  final String name;
  final String logoUrl;
  final String status; // active, coming_soon, maintenance
  final String colorHex;
  final int displayOrder;

  ServiceModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.status,
    required this.colorHex,
    required this.displayOrder,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
      status: json['status'] ?? 'coming_soon',
      colorHex: json['color_hex'] ?? '#000000',
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
