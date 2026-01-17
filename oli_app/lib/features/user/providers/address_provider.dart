import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import '../models/address_model.dart';

// Provider global pour la liste des adresses
final addressProvider = StateNotifierProvider<AddressNotifier, AsyncValue<List<Address>>>((ref) {
  return AddressNotifier();
});

// Provider pour obtenir l'adresse par défaut uniquement
final defaultAddressProvider = Provider<Address?>((ref) {
  final addresses = ref.watch(addressProvider);
  return addresses.when(
    data: (list) {
      if (list.isEmpty) return null;
      try {
        return list.firstWhere((a) => a.isDefault);
      } catch (_) {
        return list.first;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

class AddressNotifier extends StateNotifier<AsyncValue<List<Address>>> {
  AddressNotifier() : super(const AsyncValue.loading());
  
  final _storage = SecureStorageService();
  final _dio = Dio();

  Future<void> loadAddresses() async {
    state = const AsyncValue.loading();
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception("Non authentifié");

      final response = await _dio.get(
        '${ApiConfig.baseUrl}/addresses',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      final List data = response.data;
      final addresses = data.map((e) => Address.fromJson(e)).toList();
      state = AsyncValue.data(addresses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAddress(Address address) async {
    try {
      final token = await _storage.getToken();
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/addresses',
        data: address.toJson(),
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      // Reload to get fresh list with correct default flags
      await loadAddresses();
    } catch (e) {
      throw Exception("Erreur ajout adresse");
    }
  }

  Future<void> updateAddress(int id, Address address) async {
    try {
      final token = await _storage.getToken();
      await _dio.put(
        '${ApiConfig.baseUrl}/addresses/$id',
        data: address.toJson(),
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      await loadAddresses();
    } catch (e) {
      throw Exception("Erreur modification adresse");
    }
  }

  Future<void> deleteAddress(int id) async {
    try {
      final token = await _storage.getToken();
      await _dio.delete(
        '${ApiConfig.baseUrl}/addresses/$id',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      await loadAddresses();
    } catch (e) {
      throw Exception("Erreur suppression adresse");
    }
  }

  Future<void> setDefaultAddress(int id) async {
    try {
      final token = await _storage.getToken();
      await _dio.post(
        '${ApiConfig.baseUrl}/addresses/$id/set-default',
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      await loadAddresses();
    } catch (e) {
      throw Exception("Erreur définition adresse par défaut");
    }
  }
}
