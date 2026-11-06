import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../core/router/network/dio_provider.dart';
import '../models/ticket_model.dart';

/// Événement du catalogue (onglet « Explorer »).
class OEvent {
  final int id;
  final String title;
  final String subtitle;
  final String category;
  final String date;
  final String time;
  final String location;
  final String? imageUrl;
  final double minPriceFC;
  final int remaining;
  final bool hasUnlimited;
  final int typeCount;

  const OEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.date,
    required this.time,
    required this.location,
    this.imageUrl,
    required this.minPriceFC,
    required this.remaining,
    this.hasUnlimited = false,
    this.typeCount = 0,
  });

  /// Texte des places : « illimité », nombre restant, ou « Complet ».
  String get placesLabel {
    if (typeCount == 0) return 'Bientôt en vente';
    if (hasUnlimited) return 'Places disponibles';
    return remaining > 0 ? '$remaining place(s)' : 'Complet';
  }

  bool get soldOut => typeCount > 0 && !hasUnlimited && remaining <= 0;

  factory OEvent.fromJson(Map<String, dynamic> j) => OEvent(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        category: (j['category'] ?? 'autre').toString(),
        date: (j['event_date'] ?? '').toString().split('T').first,
        time: (j['event_time'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        imageUrl: j['image_url']?.toString(),
        minPriceFC: double.tryParse((j['min_price_fc'] ?? 0).toString()) ?? 0,
        remaining: int.tryParse((j['remaining'] ?? 0).toString()) ?? 0,
        hasUnlimited: j['has_unlimited'] == true,
        typeCount: int.tryParse((j['type_count'] ?? 0).toString()) ?? 0,
      );
}

/// Mes billets (GET /tickets/my).
final myTicketsProvider = FutureProvider<List<OTicket>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(ApiConfig.oticketMyTickets);
  final list = (res.data as List?) ?? const [];
  final out = <OTicket>[];
  for (final e in list) {
    try {
      out.add(OTicket.fromApi(e as Map<String, dynamic>));
    } catch (err) {
      debugPrint('⚠️ Billet ignoré (format inattendu): $err');
    }
  }
  return out;
});

/// Catalogue des événements publiés (GET /tickets/events).
final oticketEventsProvider = FutureProvider<List<OEvent>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(ApiConfig.oticketEvents);
  final list = (res.data as List?) ?? const [];
  return list.map((e) => OEvent.fromJson(e as Map<String, dynamic>)).toList();
});

/// Détail d'un événement : catégories de billets disponibles.
final oticketEventDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, eventId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(ApiConfig.oticketEventDetail(eventId));
  return (res.data as Map).cast<String, dynamic>();
});

/// Achète des billets. Renvoie null si l'achat a réussi, sinon le message d'erreur.
Future<String?> purchaseTickets(WidgetRef ref, int ticketTypeId, int quantity) async {
  try {
    await ref.read(dioProvider).post(
          ApiConfig.oticketPurchase,
          data: {'ticket_type_id': ticketTypeId, 'quantity': quantity},
        );
    ref.invalidate(myTicketsProvider);
    ref.invalidate(oticketEventsProvider);
    return null;
  } catch (e) {
    final data = (e as dynamic).response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Achat impossible pour le moment.';
  }
}

/// Événement dont l'utilisateur connecté est l'organisateur.
class OrganizerEvent {
  final int id;
  final String title;
  final String date;
  final String location;
  final String status;
  final int sold;
  final int checkedIn;

  const OrganizerEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.sold,
    required this.checkedIn,
  });

  factory OrganizerEvent.fromJson(Map<String, dynamic> j) => OrganizerEvent(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        date: (j['event_date'] ?? '').toString().split('T').first,
        location: (j['location'] ?? '').toString(),
        status: (j['status'] ?? 'draft').toString(),
        sold: int.tryParse((j['sold'] ?? 0).toString()) ?? 0,
        checkedIn: int.tryParse((j['checked_in'] ?? 0).toString()) ?? 0,
      );
}

/// Mes événements en tant qu'organisateur (liste vide si l'utilisateur n'en a aucun).
final organizerEventsProvider = FutureProvider<List<OrganizerEvent>>((ref) async {
  try {
    final res = await ref.read(dioProvider).get(ApiConfig.oticketOrganizerEvents);
    final list = (res.data as List?) ?? const [];
    return list.map((e) => OrganizerEvent.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return const [];
  }
});

/// Résultat d'un scan de billet.
class ScanOutcome {
  final String result; // valid | already_used | wrong_event | cancelled | not_found | forbidden | error
  final String message;
  final String? detail;

  const ScanOutcome(this.result, this.message, [this.detail]);
}

/// Valide un billet scanné pour un événement donné.
Future<ScanOutcome> validateTicket(WidgetRef ref, String ticketCode, int eventId) async {
  try {
    final res = await ref.read(dioProvider).post(
          ApiConfig.oticketValidate,
          data: {'ticket_code': ticketCode, 'event_id': eventId},
        );
    final data = (res.data as Map).cast<String, dynamic>();
    final t = data['ticket'];
    final detail = t is Map ? [t['type'], t['seat']].where((e) => e != null && '$e'.isNotEmpty).join(' · ') : null;
    return ScanOutcome(
      (data['result'] ?? 'valid').toString(),
      (data['message'] ?? 'Entrée autorisée').toString(),
      (detail != null && detail.isNotEmpty) ? detail : null,
    );
  } catch (e) {
    final data = (e as dynamic).response?.data;
    if (data is Map) {
      return ScanOutcome(
        (data['result'] ?? 'error').toString(),
        (data['message'] ?? data['error'] ?? 'Validation impossible').toString(),
        data['used_at'] != null ? 'Déjà scanné le ${data['used_at'].toString().substring(0, 16).replaceFirst('T', ' à ')}' : null,
      );
    }
    return const ScanOutcome('error', 'Réseau indisponible');
  }
}
