import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  // Intercepteur : injection automatique du token d'authentification
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

  return dio;
});
