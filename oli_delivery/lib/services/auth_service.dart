import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/api_config.dart';
import '../core/providers/dio_provider.dart';
import '../core/providers/storage_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthService({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendOtpEndpoint,
        data: {'phone': phoneNumber},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Send OTP error: $e');
      return false;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtpEndpoint,
        data: {
          'phone': phoneNumber,
          'otpCode': otpCode,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Verify OTP error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
}
