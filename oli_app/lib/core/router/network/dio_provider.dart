import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
    onError: (DioException e, handler) async {
      if (e.response?.statusCode == 401) {
        // Bug #1 fix: Token expiré → supprimer le token ET notifier l'AuthController
        // pour forcer la redirection vers le login (évite la "déconnexion fantôme").
        await storage.deleteAll();
        ref.read(forceLogoutCallbackProvider)();
      }
      handler.next(e);
    },
  ));

  return dio;
});

/// Provider public exposé pour être overridé dans main.dart avec le vrai callback.
/// Permet à dioProvider de déclencher forceLogout sans dépendance circulaire.
final forceLogoutCallbackProvider = Provider<void Function()>((ref) => () {});
