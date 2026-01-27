import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';

// Modèle de données pour un Service
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

// Provider pour récupérer la liste des services
final servicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  final dio = Dio();
  try {
    // URL publique des services
    final response = await dio.get('${ApiConfig.baseUrl}/services');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => ServiceModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  } catch (e) {
    print('Error fetching services: $e');
    return []; 
  }
});
