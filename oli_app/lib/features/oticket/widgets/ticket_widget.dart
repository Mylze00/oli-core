import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/ticket_model.dart';
import 'ticket_clipper.dart';

class TicketWidget extends StatelessWidget {
  final OTicket ticket;
  final bool compact;

  const TicketWidget({
    super.key,
    required this.ticket,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double width  = compact ? 300 : 340;
    final double height = compact ? 460 : 530;

    return ClipPath(
      clipper: const TicketClipper(notchPosition: 0.62, notchRadius: 20),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // ── Section haute ──
            Expanded(
              flex: 61,
              child: ticket.imageUrl != null
                  ? _buildTopSectionWithImage()
                  : _buildTopSection(),
            ),

            // ── Séparateur pointillé ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _notchCircle(),
                  Expanded(
                    child: CustomPaint(
                      painter: const DashLinePainter(color: Color(0xFF3A3A5C)),
                      size: const Size(double.infinity, 1),
                    ),
                  ),
                  _notchCircle(),
                ],
              ),
            ),

            // ── Section basse (QR) ──
            Expanded(
              flex: 39,
              child: _buildBottomSection(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nouvelle section avec image d'événement ──
  Widget _buildTopSectionWithImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image de l'événement
        SizedBox(
          height: compact ? 120 : 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: Image.network(
                  ticket.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: ticket.color.withOpacity(0.2),
                    child: Icon(
                      _getCategoryIconData(),
                      color: ticket.color.withOpacity(0.5),
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Gradient overlay en bas de l'image
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1A1A2E),
                      ],
                    ),
                  ),
                ),
              ),
              // Badge catégorie en haut à gauche
              Positioned(
                top: 12,
                left: 12,
                child: _badge(ticket.categoryLabel, ticket.color),
              ),
              // Badge statut en haut à droite
              if (!ticket.isValid)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _badge(ticket.statusLabel, Colors.grey, textColor: Colors.white),
                ),
            ],
          ),
        ),

        // Contenu texte sous l'image
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  ticket.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  ticket.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Infos : date & heure
                _infoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'DATE',
                  value: ticket.date,
                  icon2: Icons.access_time_outlined,
                  label2: 'HEURE',
                  value2: ticket.time,
                ),

                const SizedBox(height: 10),

                // Infos : lieu & siège
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: 'LIEU',
                  value: ticket.location,
                ),

                const SizedBox(height: 8),

                _infoRow(
                  icon: Icons.event_seat_outlined,
                  label: 'PLACE',
                  value: ticket.seat,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section haute originale (sans image) ──
  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge catégorie + statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge(ticket.categoryLabel, ticket.color),
              if (!ticket.isValid)
                _badge(ticket.statusLabel, Colors.grey, textColor: Colors.white),
            ],
          ),

          const SizedBox(height: 20),

          // Icône selon catégorie
          _categoryIcon(),

          const SizedBox(height: 14),

          // Titre
          Text(
            ticket.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          Text(
            ticket.subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          // Infos : date & heure
          _infoRow(
            icon: Icons.calendar_today_outlined,
            label: 'DATE',
            value: ticket.date,
            icon2: Icons.access_time_outlined,
            label2: 'HEURE',
            value2: ticket.time,
          ),

          const SizedBox(height: 14),

          // Infos : lieu & siège
          _infoRow(
            icon: Icons.location_on_outlined,
            label: 'LIEU',
            value: ticket.location,
          ),

          const SizedBox(height: 10),

          _infoRow(
            icon: Icons.event_seat_outlined,
            label: 'PLACE',
            value: ticket.seat,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF16213E),
            ticket.color.withOpacity(0.12),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // QR Code (désaturé si billet utilisé/expiré)
          ColorFiltered(
            colorFilter: ticket.isValid
                ? const ColorFilter.mode(Colors.transparent, BlendMode.saturation)
                : const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ]),
            child: QrImageView(
              data: ticket.qrData,
              version: QrVersions.auto,
              size: 110,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
            ),
          ),

          const SizedBox(height: 10),

          // Code texte
          Text(
            ticket.id,
            style: TextStyle(
              color: ticket.color,
              letterSpacing: 3,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            ticket.isValid ? '✓ Présenter ce QR code à l\'entrée' : '✗ Ce billet n\'est plus valide',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, {Color textColor = Colors.black}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }

  IconData _getCategoryIconData() {
    switch (ticket.category) {
      case TicketCategory.concert:   return Icons.music_note;
      case TicketCategory.sport:     return Icons.sports_soccer;
      case TicketCategory.cinema:    return Icons.movie_outlined;
      case TicketCategory.event:     return Icons.celebration;
      case TicketCategory.transport: return Icons.directions_bus;
    }
  }

  Widget _categoryIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ticket.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_getCategoryIconData(), color: ticket.color, size: 26),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    IconData? icon2,
    String? label2,
    String? value2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _infoCell(icon: icon, label: label, value: value)),
        if (icon2 != null && label2 != null && value2 != null) ...[
          const SizedBox(width: 16),
          Expanded(child: _infoCell(icon: icon2, label: label2, value: value2)),
        ],
      ],
    );
  }

  Widget _infoCell({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notchCircle() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3A3A5C)),
      ),
    );
  }
}
