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
  });

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
