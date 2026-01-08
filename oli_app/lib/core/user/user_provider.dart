import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'dart:convert';
import '../../secure_storage_service.dart';

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
    return User.fromJson(jsonDecode(response.body));
  }

  throw Exception('Erreur lors du chargement utilisateur');
});
