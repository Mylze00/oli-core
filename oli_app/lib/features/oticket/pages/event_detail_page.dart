import 'package:oli_app/core/widgets/oli_image.dart';
import '../widgets/oticket_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_model.dart';
import '../providers/oticket_provider.dart';
import '../../../core/theme/oli_glass.dart';

/// Page plein écran d'un événement : affiche, catégories de billets et achat.
/// Renvoie `true` à la page appelante lorsqu'un billet a été acheté.
class EventDetailPage extends ConsumerStatefulWidget {
  final OEvent event;

  const EventDetailPage({super.key, required this.event});

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  static const _background = Color(0xFF0A0A18);
  static const _surface = Color(0xFF14142B);
  static const _accent = oticketDarkBlue;

  /// Catégorie en cours d'achat : bloque les boutons pour éviter un double débit.
  int? _buyingTypeId;

  OEvent get _event => widget.event;

  @override
  void initState() {
    super.initState();
    // Le fournisseur garde son résultat en cache : on actualise les places restantes.
    Future.microtask(() {
      if (mounted) ref.invalidate(oticketEventDetailProvider(_event.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _event.toPreviewTicket();
    final detail = ref.watch(oticketEventDetailProvider(_event.id));

    return Scaffold(
      backgroundColor: _background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPoster(ticket),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _buildInfos(ticket),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: Text(
                'Catégories de billets',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: detail.when(
                loading: () => const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
                error: (_, __) => _buildDetailError(),
                data: (data) {
                  final types = (data['ticket_types'] as List?) ?? const [];
                  if (types.isEmpty) {
                    return const Text('Aucun billet en vente pour le moment.',
                        style: TextStyle(color: Colors.white54, fontSize: 14));
                  }
                  return Column(children: types.map(_buildTypeCard).toList());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Affiche entière, sans recadrage ──
  Widget _buildPoster(OTicket ticket) {
    final url = _event.imageUrl;
    final fallback = Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ticket.color.withValues(alpha: 0.55), ticket.color.withValues(alpha: 0.12)],
        ),
      ),
      child: const Icon(Icons.confirmation_number, color: Colors.white70, size: 64),
    );
    if (url == null || url.isEmpty) return fallback;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 220,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: OliImage.network(
        url,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildInfos(OTicket ticket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ticket.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            ticket.categoryLabel,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          ticket.title,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
        ),
        if (ticket.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(ticket.subtitle, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        ],
        const SizedBox(height: 16),
        _infoRow(Icons.calendar_today_outlined, 'DATE ET HEURE',
            [ticket.date, ticket.time].where((s) => s.isNotEmpty).join(' · ')),
        const SizedBox(height: 12),
        _infoRow(Icons.location_on_outlined, 'LIEU', ticket.location),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(dynamic type) {
    final id = (type['id'] as num).toInt();
    final name = type['name'].toString();
    final unlimited = type['unlimited'] == true;
    final remaining = unlimited ? 1 : (int.tryParse((type['remaining'] ?? 0).toString()) ?? 0);
    final price = double.tryParse((type['price_fc'] ?? 0).toString()) ?? 0;
    final available = remaining > 0;
    final buying = _buyingTypeId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  unlimited
                      ? 'Places disponibles'
                      : (available ? '$remaining place(s) disponible(s)' : 'Épuisé'),
                  style: TextStyle(
                      color: available ? Colors.white54 : Colors.redAccent, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  price > 0 ? '${price.toStringAsFixed(0)} FC' : 'Gratuit',
                  style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: available && _buyingTypeId == null ? () => _buy(id, name, price) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              disabledBackgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: buying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    available ? (price > 0 ? 'Acheter' : 'Réserver') : 'Épuisé',
                    style: TextStyle(
                      color: available ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailError() {
    return Column(
      children: [
        const Text('Billets indisponibles', style: TextStyle(color: Colors.white54, fontSize: 14)),
        TextButton(
          onPressed: () => ref.invalidate(oticketEventDetailProvider(_event.id)),
          child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _buy(int ticketTypeId, String name, double price) async {
    final confirmed = await showOliConfirmDialog(
      context,
      title: 'Confirmer l\'achat',
      message: price > 0
          ? 'Un billet « $name » à ${price.toStringAsFixed(0)} FC sera payé depuis votre wallet Oli.'
          : 'Vous allez réserver un billet gratuit « $name ».',
    );
    if (!confirmed || !mounted) return;

    setState(() => _buyingTypeId = ticketTypeId);
    final error = await purchaseTickets(ref, ticketTypeId, 1);
    if (!mounted) return;
    setState(() => _buyingTypeId = null);
    ref.invalidate(oticketEventDetailProvider(_event.id));

    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
    );
  }
}
