import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import 'oticket_colors.dart';
import 'ticket_clipper.dart';

const _cardDarkColor = Color(0xFF1A1A2E);
const _designWidth = 322.0;
const _designHeight = 379.0;
const _outerRadius = 17.0;
const _borderWidth = 1.5;
const _months = ['JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUIN', 'JUIL', 'AOÛT', 'SEP', 'OCT', 'NOV', 'DÉC'];

/// Carte d'un événement à l'affiche, dessinée aux proportions de la maquette.
/// Elle s'agrandit ou se réduit d'un bloc selon la largeur de l'écran.
class EventTicketCard extends StatelessWidget {
  /// Hauteur de la carte pour une largeur donnée.
  static double heightFor(double width) => width * _designHeight / _designWidth;

  final OTicket ticket;
  final String priceCaption;
  final String priceLabel;
  final String buttonLabel;
  final bool isDisabled;
  final VoidCallback onOpen;

  const EventTicketCard({
    super.key,
    required this.ticket,
    required this.priceCaption,
    required this.priceLabel,
    required this.buttonLabel,
    required this.isDisabled,
    required this.onOpen,
  });

  /// La date reçue au format AAAA-MM-JJ s'affiche « 26 NOV 2026 ».
  String get _displayDate {
    final date = DateTime.tryParse(ticket.date);
    if (date == null) return ticket.date.toUpperCase();
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// L'heure reçue au format 15:00:00 s'affiche « 15h00 ».
  String get _displayTime {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(ticket.time);
    return match == null ? ticket.time : '${match[1]}h${match[2]}';
  }

  bool get _hasImage => ticket.imageUrl != null && ticket.imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: Container(
          width: _designWidth,
          height: _designHeight,
          padding: const EdgeInsets.all(_borderWidth),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_outerRadius)),
          // Le contenu est découpé à l'intérieur du contour, qui reste entier dans les angles
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_outerRadius - _borderWidth),
            child: ColoredBox(
              color: _cardDarkColor,
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, right: 0, height: 124, child: _buildHero()),
                  Positioned(
                    top: 276,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _cardDarkColor,
                            Color.alphaBlend(ticket.color.withValues(alpha: 0.32), _cardDarkColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 7, left: 7, child: _buildBadge()),
                  Positioned(
                    top: 129,
                    left: 17,
                    right: 17,
                    child: _buildText(
                      ticket.title,
                      const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (ticket.subtitle.isNotEmpty)
                    Positioned(
                      top: 151,
                      left: 17,
                      right: 17,
                      child: _buildText(ticket.subtitle, const TextStyle(color: Colors.white54, fontSize: 9.5)),
                    ),
                  Positioned(
                    top: 171,
                    left: 17,
                    width: 150,
                    child: _buildInfo(Icons.calendar_today_outlined, 'DATE', _displayDate),
                  ),
                  Positioned(
                    top: 171,
                    left: 167,
                    right: 12,
                    child: _buildInfo(Icons.access_time_outlined, 'HEURE', _displayTime),
                  ),
                  Positioned(
                    top: 203,
                    left: 17,
                    right: 17,
                    child: _buildInfo(Icons.location_on_outlined, 'LIEU', ticket.location.toUpperCase()),
                  ),
                  Positioned(
                    top: 233,
                    left: 17,
                    right: 17,
                    child: _buildInfo(Icons.event_seat_outlined, 'PLACE', ticket.seat.toUpperCase()),
                  ),
                  Positioned(top: 268, left: 17, right: 17, height: 8, child: _buildDivider()),
                  Positioned(
                    top: 292,
                    left: 0,
                    right: 0,
                    child: Text(
                      priceCaption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 1),
                    ),
                  ),
                  Positioned(
                    top: 305,
                    left: 8,
                    right: 8,
                    child: _buildText(
                      priceLabel,
                      const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w800, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    top: 335,
                    left: 109,
                    width: 104,
                    height: 29,
                    child: ElevatedButton(
                      onPressed: onOpen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDisabled ? Colors.grey[800] : oticketDarkBlue,
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText(String value, TextStyle style, {TextAlign? textAlign}) {
    return Text(value, style: style, textAlign: textAlign, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // L'image s'arrête juste avant le bas du dégradé pour ne laisser aucun filet clair
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _hasImage
              ? OliImage.network(ticket.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildHeroFallback())
              : _buildHeroFallback(),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _cardDarkColor],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ticket.color.withValues(alpha: 0.55), ticket.color.withValues(alpha: 0.12)],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ticket.color, borderRadius: BorderRadius.circular(5)),
      child: Text(
        ticket.categoryLabel,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 9.5),
      ),
    );
  }

  Widget _buildInfo(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 11),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildText(label, const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.8)),
              const SizedBox(height: 1),
              _buildText(value, const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    Widget ring() => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3A3A5C)),
      ),
    );
    return Row(
      children: [
        ring(),
        const Expanded(
          child: CustomPaint(
            painter: DashLinePainter(color: Color(0xFF3A3A5C), strokeWidth: 1),
            size: Size(double.infinity, 1),
          ),
        ),
        ring(),
      ],
    );
  }
}
