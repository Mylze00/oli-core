import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/ticket_model.dart';
import 'ticket_clipper.dart';

class TicketWidget extends StatelessWidget {
  final OTicket ticket;
  final bool compact;

  /// Remplace le QR code en bas du billet (aperçu d'un événement non acheté).
  final Widget? footer;

  /// Part de hauteur (sur 100) réservée à la section haute.
  final int topFlex;

  const TicketWidget({
    super.key,
    required this.ticket,
    this.compact = false,
    this.footer,
    this.topFlex = 61,
  });

  /// Vrai si l'événement possède une image exploitable.
  bool get _hasImage => ticket.imageUrl != null && ticket.imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final double width  = compact ? 300 : 340;
    final double height = compact ? 460 : 530;

    // La hauteur du billet est fixe : on limite l'agrandissement du texte
    // pour que les informations et le QR code restent lisibles.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ClipPath(
        // Position alignée sur la ligne pointillée.
        clipper: TicketClipper(notchPosition: topFlex / 100 * 0.98 + 0.01, notchRadius: 20),
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
                flex: topFlex,
                child: _buildTopSection(),
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
                flex: 100 - topFlex,
                child: _buildBottomSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section haute : visuel en bandeau puis informations ──
  // Le visuel occupe la place laissée par le texte, qui ne peut donc
  // jamais déborder sur la ligne pointillée.
  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildHero()),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              if (ticket.subtitle.isNotEmpty) ...[
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
              ],

              const SizedBox(height: 10),

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
      ],
    );
  }

  // ── Bandeau : image de l'événement, ou visuel de catégorie à défaut ──
  Widget _buildHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: _hasImage
              ? Image.network(
                  ticket.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _heroFallback(),
                )
              : _heroFallback(),
        ),
        // Dégradé en bas du bandeau
        const Positioned(
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
                  Color(0xFF1A1A2E),
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
    );
  }

  Widget _heroFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            ticket.color.withOpacity(0.55),
            ticket.color.withOpacity(0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIconData(),
          color: Colors.white.withOpacity(0.75),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
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
      child: footer ?? Column(
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
