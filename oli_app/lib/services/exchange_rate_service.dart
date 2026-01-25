import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service pour gérer les taux de change
class ExchangeRateService {
  static const String baseUrl = 'https://oli-core.onrender.com/api/exchange-rate';

  /// Récupérer le taux de change actuel
  Future<Map<String, dynamic>> getCurrentRate({
    String from = 'USD',
    String to = 'CDF',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/current?from=$from&to=$to'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      throw Exception('Erreur lors de la récupération du taux');
    } catch (e) {
      print('[EXCHANGE SERVICE] Erreur getCurrentRate: $e');
      rethrow;
    }
  }

  /// Convertir un montant d'une devise à une autre
  Future<Map<String, dynamic>> convertAmount({
    required double amount,
    String from = 'USD',
    String to = 'CDF',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/convert?amount=$amount&from=$from&to=$to'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      throw Exception('Erreur lors de la conversion');
    } catch (e) {
      print('[EXCHANGE SERVICE] Erreur convertAmount: $e');
      rethrow;
    }
  }

  /// Récupérer l'historique des taux
  Future<List<Map<String, dynamic>>> getRateHistory({
    String from = 'USD',
    String to = 'CDF',
    int days = 30,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/history?from=$from&to=$to&days=$days'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['history']);
        }
      }

      throw Exception('Erreur lors de la récupération de l\'historique');
    } catch (e) {
      print('[EXCHANGE SERVICE] Erreur getRateHistory: $e');
      rethrow;
    }
  }

  /// Récupérer les statistiques des taux
  Future<Map<String, dynamic>> getStatistics({
    String from = 'USD',
    String to = 'CDF',
    int days = 30,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/statistics?from=$from&to=$to&days=$days'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['statistics'];
        }
      }

      throw Exception('Erreur lors de la récupération des statistiques');
    } catch (e) {
      print('[EXCHANGE SERVICE] Erreur getStatistics: $e');
      rethrow;
    }
  }
}
