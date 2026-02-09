import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
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
      error: error ?? this.error,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }

  /// Nombre de commandes à traiter (payées mais non traitées)
  int get pendingCount => statusCounts['paid'] ?? 0;
}

/// Notifier Riverpod pour les commandes vendeur
class SellerOrdersNotifier extends StateNotifier<SellerOrdersState> {
  final Ref _ref;

  SellerOrdersNotifier(this._ref) : super(const SellerOrdersState());

  Dio get _dio => _ref.read(dioProvider);

  /// Charger les commandes vendeur
  Future<void> fetchOrders({String? status}) async {
    state = state.copyWith(isLoading: true, error: null, currentFilter: status);

    try {
      final queryParams = status != null ? {'status': status} : <String, dynamic>{};
      
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/seller/orders',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        state = state.copyWith(
          isLoading: false,
          error: 'Vous devez être vendeur pour accéder à cette section',
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.message ?? 'Erreur réseau');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Charger les statistiques
  Future<void> fetchStats() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/seller/orders/stats/summary',
      );

      if (response.statusCode == 200) {
        state = state.copyWith(stats: SellerOrderStats.fromJson(response.data));
      }
    } catch (e) {
      debugPrint('Erreur fetching seller stats: $e');
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
      final body = <String, dynamic>{'status': newStatus};

      if (trackingNumber != null) body['tracking_number'] = trackingNumber;
      if (carrier != null) body['carrier'] = carrier;
      if (estimatedDelivery != null) body['estimated_delivery'] = estimatedDelivery;
      if (notes != null) body['notes'] = notes;

      final response = await _dio.patch(
        '${ApiConfig.baseUrl}/api/seller/orders/$orderId/status',
        data: body,
      );

      if (response.statusCode == 200) {
        await loadAll();
        return true;
      }
      
      state = state.copyWith(error: response.data?['error'] ?? 'Erreur mise à jour');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: e.response?.data?['error'] ?? 'Erreur réseau');
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Obtenir les détails d'une commande
  Future<SellerOrder?> getOrderDetails(int orderId) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/seller/orders/$orderId',
      );

      if (response.statusCode == 200) {
        return SellerOrder.fromJson(response.data);
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
  (ref) => SellerOrdersNotifier(ref),
);

/// Provider pour les stats uniquement (plus léger)
final sellerStatsProvider = FutureProvider<SellerOrderStats?>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get(
      '${ApiConfig.baseUrl}/api/seller/orders/stats/summary',
    );

    if (response.statusCode == 200) {
      return SellerOrderStats.fromJson(response.data);
    }
    return null;
  } catch (e) {
    return null;
  }
});
