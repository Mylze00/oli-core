import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_order_model.dart';
import '../services/delivery_service.dart';

// État
class DeliveryState {
  final List<DeliveryOrder> availableOrders;
  final List<DeliveryOrder> myTasks;
  final bool isLoading;
  final String? error;

  DeliveryState({
    this.availableOrders = const [],
    this.myTasks = const [],
    this.isLoading = false,
    this.error,
  });

  DeliveryState copyWith({
    List<DeliveryOrder>? availableOrders,
    List<DeliveryOrder>? myTasks,
    bool? isLoading,
    String? error,
  }) {
    return DeliveryState(
      availableOrders: availableOrders ?? this.availableOrders,
      myTasks: myTasks ?? this.myTasks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Notifier — utilise le deliveryServiceProvider injecté
class DeliveryNotifier extends StateNotifier<DeliveryState> {
  final DeliveryService _service;

  DeliveryNotifier(this._service) : super(DeliveryState());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _service.getAvailableDeliveries(),
        _service.getMyTasks(),
      ]);
      state = state.copyWith(
        availableOrders: results[0],
        myTasks: results[1],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> acceptOrder(int id) async {
    try {
      await _service.acceptDelivery(id);
      await loadData();
    } catch (e) {
      state = state.copyWith(error: "Erreur lors de l'acceptation : $e");
    }
  }

  Future<void> updateStatus(int id, String status) async {
    try {
      await _service.updateStatus(id, status);
      await loadData();
    } catch (e) {
      state = state.copyWith(error: "Erreur mise à jour statut : $e");
    }
  }
}

// Provider
final deliveryProvider = StateNotifierProvider<DeliveryNotifier, DeliveryState>((ref) {
  final service = ref.read(deliveryServiceProvider);
  return DeliveryNotifier(service);
});
