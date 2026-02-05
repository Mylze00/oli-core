import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'storage_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Add token if it exists
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      print('Request: [${options.method}] ${options.path}');
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      print('Error: [${e.response?.statusCode}] ${e.message}');
      return handler.next(e);
    },
    onResponse: (response, handler) {
      print('Response: [${response.statusCode}] ${response.requestOptions.path}');
      return handler.next(response);
    },
  ));

  return dio;
});
