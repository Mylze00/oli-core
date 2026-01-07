import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// On définit l'état du paiement
class PaymentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const PaymentState({this.isLoading = false, this.error, this.isSuccess = false});

  PaymentState copyWith({bool? isLoading, String? error, bool? isSuccess}) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Le Provider pour accéder au contrôleur
final paymentControllerProvider = StateNotifierProvider<PaymentController, PaymentState>((ref) {
  return PaymentController();
});

class PaymentController extends StateNotifier<PaymentState> {
  PaymentController() : super(const PaymentState());

  // URL de votre backend (ajustez selon votre config)
  final String paymentUrl = 'http://127.0.0.1:3000/payment/initiate';

  Future<bool> processPayment({
    required String amount,
    required String phoneNumber,
    required String provider, // ex: 'M-PESA', 'ORANGE'
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final response = await http.post(
        Uri.parse(paymentUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'phone': phoneNumber,
          'method': provider,
        }),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Échec du paiement');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur réseau');
      return false;
    }
  }
}