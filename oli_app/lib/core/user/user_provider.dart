import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage_service.dart';
import '../router/network/dio_provider.dart';
import 'user_model.dart';

final userProvider = FutureProvider<User>((ref) async {
  final dio = ref.read(dioProvider);
  
  final response = await dio.get(ApiConfig.authMe);

  if (response.statusCode == 200) {
    final data = response.data;
    return User.fromJson(data['user'] ?? data);
  }

  throw Exception('Erreur lors du chargement utilisateur');
});
