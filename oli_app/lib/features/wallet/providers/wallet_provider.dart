import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/transaction_model.dart';

// --- STATE ---
class WalletState {
  final double balance;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final String? error;

  WalletState({
    this.balance = 0.0, 
    this.transactions = const [], 
    this.isLoading = false,
    this.error
  });

  WalletState copyWith({
    double? balance,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// --- PROVIDER ---
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

// --- NOTIFIER ---
class WalletNotifier extends StateNotifier<WalletState> {
  final _storage = SecureStorageService();

  WalletNotifier() : super(WalletState());

  Future<void> loadWalletData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception("Non authentifié");

      // 1. Fetch Balance
      final balRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/wallet/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      double balance = 0.0;
      if (balRes.statusCode == 200) {
        final data = jsonDecode(balRes.body);
        balance = double.parse(data['balance'].toString());
      }

      // 2. Fetch History
      final histRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/wallet/transactions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      List<WalletTransaction> transactions = [];
      if (histRes.statusCode == 200) {
        final List list = jsonDecode(histRes.body);
        transactions = list.map((e) => WalletTransaction.fromJson(e)).toList();
      }

      state = state.copyWith(
        isLoading: false,
        balance: balance,
        transactions: transactions,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> deposit({required double amount, required String provider, required String phone}) async {
    return _performTransaction('/wallet/deposit', {
      'amount': amount,
      'provider': provider,
      'phoneNumber': phone
    });
  }

  Future<bool> withdraw({required double amount, required String provider, required String phone}) async {
    return _performTransaction('/wallet/withdraw', {
      'amount': amount,
      'provider': provider,
      'phoneNumber': phone
    });
  }

  Future<bool> _performTransaction(String endpoint, Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await _storage.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Reload data to reflect new balance
        await loadWalletData(); 
        return true;
      } else {
        final err = jsonDecode(response.body);
        state = state.copyWith(isLoading: false, error: err['error'] ?? 'Erreur inconnue');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
