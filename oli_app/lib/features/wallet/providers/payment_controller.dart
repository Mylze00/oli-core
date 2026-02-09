import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';

// On définit l'état du paiement
class PaymentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const PaymentState({this.isLoading = false, this.error, this.isSuccess = false});

  PaymentState copyWith({bool? isLoading, String? error, bool? isSuccess}) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Le Provider pour accéder au contrôleur
final paymentControllerProvider = StateNotifierProvider<PaymentController, PaymentState>((ref) {
  return PaymentController(ref);
});

class PaymentController extends StateNotifier<PaymentState> {
  final Ref _ref;

  PaymentController(this._ref) : super(const PaymentState());

  Dio get _dio => _ref.read(dioProvider);

  Future<bool> processPayment({
    required String amount,
    required String phoneNumber,
    required String provider, // ex: 'M-PESA', 'ORANGE'
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/payment/initiate',
        data: {
          'amount': amount,
          'phone': phoneNumber,
          'method': provider,
        },
      );

      if (response.statusCode == 200) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Échec du paiement');
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.response?.data?['error'] ?? 'Erreur réseau');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
      return false;
    }
  }
}