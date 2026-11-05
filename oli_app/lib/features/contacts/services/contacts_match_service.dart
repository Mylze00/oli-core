import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';

/// Contact Oli trouvé dans le carnet de l'utilisateur.
class ContactMatch {
  final int id;
  final String name;
  final String phone;

  const ContactMatch({required this.id, required this.name, required this.phone});

  factory ContactMatch.fromJson(Map<String, dynamic> json) => ContactMatch(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
      );
}

/// Envoie les numéros du carnet au backend et récupère les comptes Oli correspondants.
/// Les numéros ne sont ni stockés ni journalisés côté serveur.
class ContactsMatchService {
  static const int _maxPerRequest = 1000;
  final Dio _dio;

  ContactsMatchService(this._dio);

  Future<List<ContactMatch>> matchPhones(List<String> phones) async {
    final result = <ContactMatch>[];
    for (var i = 0; i < phones.length; i += _maxPerRequest) {
      final chunk = phones.sublist(i, math.min(i + _maxPerRequest, phones.length));
      final response = await _dio.post(
        ApiConfig.contactsMatch,
        data: {'phones': chunk},
      );
      final list = (response.data['matches'] as List?) ?? const [];
      result.addAll(list.map((e) => ContactMatch.fromJson(e as Map<String, dynamic>)));
    }
    return result;
  }
}
