import 'package:flutter/material.dart';

enum TicketCategory { concert, sport, cinema, event, transport }
enum TicketStatus { valid, used, expired }

class OTicket {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final String time;
  final String location;
  final String seat;
  final TicketCategory category;
  final TicketStatus status;
  final Color color;
  final String qrData;
  final String? imageUrl;

  const OTicket({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    required this.location,
    required this.seat,
    required this.category,
    required this.status,
    required this.color,
    required this.qrData,
    this.imageUrl,
  });

  /// Construit un billet à partir de la réponse de GET /tickets/my.
  factory OTicket.fromApi(Map<String, dynamic> j) {
    const palette = {
      'concert': Color(0xFFFFD700),
      'cinema': Color(0xFFE53935),
      'sport': Color(0xFF43A047),
      'conference': Color(0xFF1E88E5),
      'festival': Color(0xFF8E24AA),
      'autre': Color(0xFF00ACC1),
    };
    const cats = {
      'concert': TicketCategory.concert,
      'cinema': TicketCategory.cinema,
      'sport': TicketCategory.sport,
      'conference': TicketCategory.event,
      'festival': TicketCategory.event,
      'autre': TicketCategory.event,
    };
    final cat = (j['category'] ?? 'autre').toString();
    final status = (j['status'] ?? 'valid').toString();

    String date = '';
    final rawDate = j['event_date']?.toString();
    if (rawDate != null && rawDate.length >= 10) {
      final d = DateTime.tryParse(rawDate);
      if (d != null) {
        const mois = ['JANV','FÉVR','MARS','AVR','MAI','JUIN','JUIL','AOÛT','SEPT','OCT','NOV','DÉC'];
        date = '${d.day} ${mois[d.month - 1]} ${d.year}';
      }
    }

    return OTicket(
      id: (j['ticket_code'] ?? j['id']).toString(),
      title: (j['title'] ?? '').toString().toUpperCase(),
      subtitle: (j['subtitle'] ?? '').toString(),
      date: date,
      time: (j['event_time'] ?? '').toString(),
      location: (j['location'] ?? '').toString().toUpperCase(),
      seat: (j['seat_label'] ?? j['type_name'] ?? '').toString().toUpperCase(),
      category: cats[cat] ?? TicketCategory.event,
      status: status == 'used'
          ? TicketStatus.used
          : (status == 'valid' ? TicketStatus.valid : TicketStatus.expired),
      color: palette[cat] ?? const Color(0xFF00ACC1),
      qrData: (j['ticket_code'] ?? '').toString(),
      imageUrl: j['image_url']?.toString(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case TicketCategory.concert: return 'CONCERT';
      case TicketCategory.sport:   return 'SPORT';
      case TicketCategory.cinema:  return 'CINÉMA';
      case TicketCategory.event:   return 'ÉVÉNEMENT';
      case TicketCategory.transport: return 'TRANSPORT';
    }
  }

  String get statusLabel {
    switch (status) {
      case TicketStatus.valid:   return 'VALIDE';
      case TicketStatus.used:    return 'UTILISÉ';
      case TicketStatus.expired: return 'EXPIRÉ';
    }
  }

  bool get isValid => status == TicketStatus.valid;
}
