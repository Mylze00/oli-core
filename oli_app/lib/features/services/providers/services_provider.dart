import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';

import '../../../../models/service_model.dart';

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
