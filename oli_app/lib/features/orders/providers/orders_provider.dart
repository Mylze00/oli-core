import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../models/order_model.dart';
import '../../../core/router/network/dio_provider.dart';

/// Provider pour récupérer les commandes de l'utilisateur
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final dio = ref.read(dioProvider);
  
  try {
    final response = await dio.get(ApiConfig.orders);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((e) => Order.fromJson(e)).toList();
    }
    
    throw Exception('Erreur ${response.statusCode}');
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      throw Exception('Non authentifié');
    }
    throw Exception('Erreur réseau: ${e.message}');
  }
});

/// Service pour créer une commande
class OrderService {
  final Dio _dio;
  
  OrderService(this._dio);
  
  /// Crée la commande. Lève une [OrderException] avec le message du serveur
  /// (solde insuffisant, produit indisponible…) au lieu de renvoyer null.
  Future<Order> createOrder({
    required List<OrderItem> items,
    String? deliveryAddress,
    String paymentMethod = 'wallet',
    double deliveryFee = 0,
    String? deliveryMethodId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.orders,
        data: {
          'items': items.map((e) => e.toJson()).toList(),
          'deliveryAddress': deliveryAddress,
          'paymentMethod': paymentMethod,
          'deliveryFee': deliveryFee,
          if (deliveryMethodId != null) 'deliveryMethodId': deliveryMethodId,
        },
      );
      return Order.fromJson(response.data['order']);
    } on DioException catch (e) {
      throw OrderException.fromDio(e, 'La commande n\'a pas pu être créée.');
    }
  }

  /// Devis exact calculé par le serveur : ce qui sera réellement débité.
  Future<OrderQuote> quoteOrder({required List<OrderItem> items, double deliveryFee = 0}) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderQuote,
        data: {'items': items.map((e) => e.toJson()).toList(), 'deliveryFee': deliveryFee},
      );
      return OrderQuote.fromJson(Map<String, dynamic>.from(response.data['quote'] as Map));
    } on DioException catch (e) {
      throw OrderException.fromDio(e, 'Le montant n\'a pas pu être calculé.');
    }
  }

  
  Future<bool> cancelOrder(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderCancel(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur annulation commande: $e');
      return false;
    }
  }

  /// Envoie une demande de remboursement à l'administrateur.
  /// Retourne null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> requestRefund(int orderId, String reason) async {
    const fallback = "Impossible d'envoyer la demande de remboursement";
    try {
      await _dio.post(ApiConfig.orderRefundRequest(orderId), data: {'reason': reason});
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Erreur demande de remboursement: $e');
      final data = e.response?.data;
      return data is Map ? data['error']?.toString() ?? fallback : fallback;
    }
  }

  /// Lance le paiement Mobile Money d'une commande : renvoie l'opération à suivre
  /// (oliOrderId, montant demandé), ou lève une [OrderException].
  Future<Map<String, dynamic>> payOrderMobileMoney({
    required int orderId,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderPayMobileMoney(orderId),
        data: {'phone': phone},
      );
      return Map<String, dynamic>.from(response.data['result'] as Map);
    } on DioException catch (e) {
      throw OrderException.fromDio(e, 'Le paiement Mobile Money n\'a pas pu être lancé.');
    }
  }

  Future<bool> payOrder(int orderId, String paymentMethod) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderPay(orderId),
        data: {'paymentMethod': paymentMethod},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur paiement commande: $e');
      return false;
    }
  }

  /// Récupérer le tracking complet d'une commande
  Future<Map<String, dynamic>?> getTracking(int orderId) async {
    try {
      final response = await _dio.get(ApiConfig.orderTracking(orderId));
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur tracking: $e');
      return null;
    }
  }

  /// Vendeur: marquer en préparation
  Future<bool> markProcessing(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderPrepare(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur markProcessing: $e');
      return false;
    }
  }

  /// Vendeur: marquer comme prête
  Future<bool> markReady(int orderId) async {
    try {
      final response = await _dio.post(ApiConfig.orderReady(orderId));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur markReady: $e');
      return false;
    }
  }

  /// Livreur: valider pickup avec code
  Future<bool> verifyPickup(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderVerifyPickup(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur verifyPickup: $e');
      return false;
    }
  }

  /// Acheteur: valider livraison avec code
  Future<bool> verifyDelivery(int orderId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.orderVerifyDelivery(orderId),
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erreur verifyDelivery: $e');
      return false;
    }
  }
}

/// Provider du service de commandes
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.read(dioProvider));
});

/// Provider pour récupérer le tracking d'une commande
final orderTrackingProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, orderId) async {
  final service = ref.read(orderServiceProvider);
  return service.getTracking(orderId);
});


/// Erreur lisible renvoyée par le serveur pour une commande.
class OrderException implements Exception {
  final String message;
  const OrderException(this.message);

  factory OrderException.fromDio(DioException e, String fallback) {
    final data = e.response?.data;
    final serverMessage = data is Map ? data['error']?.toString() : null;
    if (serverMessage != null && serverMessage.isNotEmpty) return OrderException(serverMessage);
    if (e.response == null) return const OrderException('Connexion impossible. Vérifiez votre réseau et réessayez.');
    return OrderException(fallback);
  }

  @override
  String toString() => message;
}

/// Montants exacts d'une commande, tels que le serveur les débitera (en FC).
class OrderQuote {
  final double itemsTotalFC;
  final double deliveryFeeFC;
  final double totalFC;
  final double walletBalanceFC;
  final double mobileMoneyFeeFC;
  final double mobileMoneyTotalFC;
  final double exchangeRate;
  final List<QuoteLine> lines;

  const OrderQuote({
    required this.itemsTotalFC,
    required this.deliveryFeeFC,
    required this.totalFC,
    required this.walletBalanceFC,
    required this.mobileMoneyFeeFC,
    required this.mobileMoneyTotalFC,
    required this.exchangeRate,
    required this.lines,
  });

  bool get walletCovers => walletBalanceFC >= totalFC;

  factory OrderQuote.fromJson(Map<String, dynamic> json) {
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return OrderQuote(
      itemsTotalFC: n('itemsTotalFC'),
      deliveryFeeFC: n('deliveryFeeFC'),
      totalFC: n('totalFC'),
      walletBalanceFC: n('walletBalanceFC'),
      mobileMoneyFeeFC: n('mobileMoneyFeeFC'),
      mobileMoneyTotalFC: n('mobileMoneyTotalFC'),
      exchangeRate: n('exchangeRate'),
      lines: ((json['items'] as List?) ?? [])
          .map((e) => QuoteLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class QuoteLine {
  final String productId;
  final String? variantId;
  final String productName;
  final int quantity;
  final double lineTotalFC;

  const QuoteLine({
    required this.productId,
    this.variantId,
    required this.productName,
    required this.quantity,
    required this.lineTotalFC,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        productId: json['productId'].toString(),
        variantId: json['variantId']?.toString(),
        productName: json['productName']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        lineTotalFC: (json['lineTotalFC'] as num?)?.toDouble() ?? 0,
      );
}
