import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'dart:convert';
import '../storage/secure_storage_service.dart';

import 'user_model.dart';

final userProvider = FutureProvider<User>((ref) async {
  final token = await SecureStorageService().getToken();
  
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/auth/me'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return User.fromJson(data['user'] ?? data); // Support both nested and flat for robustness
  }

  throw Exception('Erreur lors du chargement utilisateur');
});
