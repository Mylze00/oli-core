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
