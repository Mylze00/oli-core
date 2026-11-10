import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../../../config/api_config.dart';

/// Contact Oli trouvé dans le carnet de l'utilisateur.
class ContactMatch {
  final int id;
  final String name;
  final String phone;
  final String? avatarUrl;

  const ContactMatch({required this.id, required this.name, required this.phone, this.avatarUrl});

  factory ContactMatch.fromJson(Map<String, dynamic> json) => ContactMatch(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        avatarUrl: json['avatar_url']?.toString(),
      );

  String get displayName => name.trim().isEmpty ? 'Utilisateur Oli' : name.trim();
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

  Future<List<ContactMatch>> fetchContacts() async {
    final response = await _dio.get(ApiConfig.contacts);
    final list = (response.data['contacts'] as List?) ?? const [];
    return list.map((e) => ContactMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Échoue en 404 si le numéro n'appartient à aucun compte Oli.
  Future<ContactMatch> addContact(String phone) async {
    final response = await _dio.post(ApiConfig.contacts, data: {'phone': phone});
    return ContactMatch.fromJson(response.data['contact'] as Map<String, dynamic>);
  }

  Future<void> removeContact(int contactId) async {
    await _dio.delete('${ApiConfig.contacts}/$contactId');
  }
}
