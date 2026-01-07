import 'package:dio/dio.dart';

class AuthApi {
  final Dio dio;

  AuthApi(this.dio);

  Future<void> sendOtp(String phone) async {
    print('🌐 POST /auth/send-otp');
    print('📞 phone = $phone');

    final response = await dio.post(
      '/auth/send-otp',
      data: {'phone': phone},
    );

    print('📥 Response: ${response.data}');
  }

  Future<void> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    await dio.post(
      '/auth/verify-otp',
      data: {
        'phone': phone,
        'otp': otpCode,
      },
    );
  }
}
