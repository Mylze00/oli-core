import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/seller_order.dart';

/// État des commandes vendeur
class SellerOrdersState {
  final List<SellerOrder> orders;
  final Map<String, int> statusCounts;
  final SellerOrderStats? stats;
  final bool isLoading;
  final String? error;
  final String? currentFilter;

  const SellerOrdersState({
    this.orders = const [],
    this.statusCounts = const {},
    this.stats,
    this.isLoading = false,
    this.error,
    this.currentFilter,
  });

  SellerOrdersState copyWith({
    List<SellerOrder>? orders,
    Map<String, int>? statusCounts,
    SellerOrderStats? stats,
    bool? isLoading,
    String? error,
    String? currentFilter,
  }) {
    return SellerOrdersState(
      orders: orders ?? this.orders,
      statusCounts: statusCounts ?? this.statusCounts,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }

  /// Nombre de commandes à traiter (payées mais non traitées)
  int get pendingCount => statusCounts['paid'] ?? 0;
}

/// Notifier Riverpod pour les commandes vendeur
class SellerOrdersNotifier extends StateNotifier<SellerOrdersState> {
  final SecureStorageService _storage = SecureStorageService();

  SellerOrdersNotifier() : super(const SellerOrdersState());

  /// Headers d'authentification
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Charger les commandes vendeur
  Future<void> fetchOrders({String? status}) async {
    state = state.copyWith(isLoading: true, error: null, currentFilter: status);

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/seller/orders').replace(
        queryParameters: status != null ? {'status': status} : null,
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orders = (data['orders'] as List)
            .map((e) => SellerOrder.fromJson(e))
            .toList();

        final statusCounts = <String, int>{};
        (data['status_counts'] as Map<String, dynamic>?)?.forEach((key, value) {
          statusCounts[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
        });

        state = state.copyWith(
          orders: orders,
          statusCounts: statusCounts,
          isLoading: false,
        );
      } else if (response.statusCode == 403) {
        state = state.copyWith(
          isLoading: false,
          error: 'Vous devez être vendeur pour accéder à cette section',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Erreur ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Charger les statistiques
  Future<void> fetchStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/orders/stats/summary'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = state.copyWith(stats: SellerOrderStats.fromJson(data));
      }
    } catch (e) {
      // Silently fail for stats
      print('Error fetching seller stats: $e');
    }
  }

  /// Charger tout (commandes + stats)
  Future<void> loadAll() async {
    await Future.wait([
      fetchOrders(),
      fetchStats(),
    ]);
  }

  /// Mettre à jour le statut d'une commande
  Future<bool> updateOrderStatus(
    int orderId,
    String newStatus, {
    String? trackingNumber,
    String? carrier,
    String? estimatedDelivery,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'status': newStatus};

      if (trackingNumber != null) body['tracking_number'] = trackingNumber;
      if (carrier != null) body['carrier'] = carrier;
      if (estimatedDelivery != null) body['estimated_delivery'] = estimatedDelivery;
      if (notes != null) body['notes'] = notes;

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/orders/$orderId/status'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Rafraîchir les données
        await loadAll();
        return true;
      }
      
      final data = jsonDecode(response.body);
      state = state.copyWith(error: data['error'] ?? 'Erreur mise à jour');
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Obtenir les détails d'une commande
  Future<SellerOrder?> getOrderDetails(int orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/seller/orders/$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SellerOrder.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Effacer l'erreur
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider global des commandes vendeur
final sellerOrdersProvider =
    StateNotifierProvider<SellerOrdersNotifier, SellerOrdersState>(
  (ref) => SellerOrdersNotifier(),
);

/// Provider pour les stats uniquement (plus léger)
final sellerStatsProvider = FutureProvider<SellerOrderStats?>((ref) async {
  final storage = SecureStorageService();
  final token = await storage.getToken();

  if (token == null) return null;

  try {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/seller/orders/stats/summary'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return SellerOrderStats.fromJson(data);
    }
    return null;
  } catch (e) {
    return null;
  }
});
