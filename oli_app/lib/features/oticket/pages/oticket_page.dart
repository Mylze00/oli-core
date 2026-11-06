import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_model.dart';
import '../providers/oticket_provider.dart';
import '../widgets/ticket_widget.dart';
import 'ticket_detail_page.dart';

class OTicketPage extends ConsumerStatefulWidget {
  const OTicketPage({super.key});

  @override
  ConsumerState<OTicketPage> createState() => _OTicketPageState();
}

class _OTicketPageState extends ConsumerState<OTicketPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTicketIndex = 0;

  // Billets réels de l'utilisateur (GET /tickets/my)
  List<OTicket> _myTickets = const [];
  List<OTicket> get _validTickets => _myTickets.where((t) => t.isValid).toList();
  List<OTicket> get _pastTickets  => _myTickets.where((t) => !t.isValid).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(myTicketsProvider);
    _myTickets = ticketsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
            error: (_, __) => _buildLoadError(),
            data: (_) => _buildMyTickets(),
          ),
          _buildExplore(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A18),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.confirmation_number, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'O-Ticket',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF7C4DFF),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'Mes Billets'),
          Tab(text: 'Explorer'),
        ],
      ),
    );
  }

  // ── Onglet Mes Billets ──
  Widget _buildMyTickets() {
    if (_myTickets.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        const SizedBox(height: 24),

        // PageView des tickets valides
        if (_validTickets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_validTickets.length} billet${_validTickets.length > 1 ? 's' : ''} actif${_validTickets.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              itemCount: _validTickets.length,
              onPageChanged: (i) => setState(() => _currentTicketIndex = i),
              itemBuilder: (context, index) {
                final ticket = _validTickets[index];
                return GestureDetector(
                  onTap: () => _openDetail(ticket),
                  child: AnimatedScale(
                    scale: _currentTicketIndex == index ? 1.0 : 0.92,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Hero(
                        tag: 'ticket-${ticket.id}',
                        child: TicketWidget(ticket: ticket),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Indicateurs de pages
          if (_validTickets.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _validTickets.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentTicketIndex == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentTicketIndex == i
                        ? const Color(0xFF7C4DFF)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],

        // Tickets passés
        if (_pastTickets.isNotEmpty) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Billets passés',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...  _pastTickets.map((t) => _buildPastTicketTile(t)),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPastTicketTile(OTicket ticket) {
    return GestureDetector(
      onTap: () => _openDetail(ticket),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Thumbnail image ou icône catégorie
            ticket.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ticket.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_categoryIcon(ticket.category), color: Colors.grey, size: 20),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(ticket.category), color: Colors.grey, size: 20),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ticket.date} · ${ticket.location}',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ticket.statusLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onglet Explorer : catalogue réel des événements publiés ──
  Widget _buildExplore() {
    final eventsAsync = ref.watch(oticketEventsProvider);

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
      error: (_, __) => _buildLoadError(),
      data: (events) {
        if (events.isEmpty) return _buildNoEvents();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(oticketEventsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, i) => _buildEventCard(events[i]),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(OEvent e) {
    return GestureDetector(
      onTap: () => _showEventSheet(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14142B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.imageUrl != null && e.imageUrl!.isNotEmpty)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(
                  e.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.image, color: Colors.white24),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      Text('${e.date}  ${e.time}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.white38),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(e.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'dès ${e.minPriceFC.toStringAsFixed(0)} FC',
                        style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        e.remaining > 0 ? '${e.remaining} place(s)' : 'Complet',
                        style: TextStyle(
                            color: e.remaining > 0 ? Colors.white54 : Colors.redAccent, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Feuille d'achat : catégories de billets et validation.
  void _showEventSheet(OEvent e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14142B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final detail = sheetRef.watch(oticketEventDetailProvider(e.id));
          return Padding(
            padding: const EdgeInsets.all(20),
            child: detail.when(
              loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))),
              error: (_, __) => const SizedBox(
                  height: 120,
                  child: Center(
                      child: Text('Détail indisponible', style: TextStyle(color: Colors.white54)))),
              data: (data) {
                final types = (data['ticket_types'] as List?) ?? const [];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text('${e.date}  ${e.time} · ${e.location}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    if (types.isEmpty)
                      const Text('Aucun billet en vente pour le moment.',
                          style: TextStyle(color: Colors.white54))
                    else
                      ...types.map((t) {
                        final remaining =
                            int.tryParse((t['remaining'] ?? 0).toString()) ?? 0;
                        final price =
                            double.tryParse((t['price_fc'] ?? 0).toString()) ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t['name'].toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text(
                            remaining > 0 ? '$remaining disponible(s)' : 'Épuisé',
                            style: TextStyle(
                                color: remaining > 0 ? Colors.white38 : Colors.redAccent,
                                fontSize: 11),
                          ),
                          trailing: ElevatedButton(
                            onPressed: remaining > 0
                                ? () => _buy(ctx, (t['id'] as num).toInt(), price)
                                : null,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C4DFF)),
                            child: Text('${price.toStringAsFixed(0)} FC',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _buy(BuildContext sheetCtx, int ticketTypeId, double price) async {
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF14142B),
        title: const Text('Confirmer l\'achat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Un billet à ${price.toStringAsFixed(0)} FC sera payé depuis votre wallet Oli.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Acheter')),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await purchaseTickets(ref, ticketTypeId, 1);
    if (!mounted) return;
    Navigator.of(sheetCtx).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Billet acheté. Retrouvez-le dans « Mes Billets ».'),
        backgroundColor: error == null ? const Color(0xFF22C55E) : Colors.redAccent,
      ),
    );
    if (error == null) _tabController.animateTo(0);
  }

  Widget _buildNoEvents() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_outlined, color: Color(0xFF7C4DFF), size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Aucun événement pour le moment',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Revenez bientôt : de nouveaux événements\nseront publiés dans votre ville.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5)),
          ],
        ),
      );

  Widget _buildLoadError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 44),
            const SizedBox(height: 12),
            const Text('Chargement impossible',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                ref.invalidate(myTicketsProvider);
                ref.invalidate(oticketEventsProvider);
              },
              child: const Text('Réessayer', style: TextStyle(color: Color(0xFF7C4DFF))),
            ),
          ],
        ),
      );


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.confirmation_number_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('Aucun billet', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Vos billets achetés sur Oli\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openDetail(OTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticket: ticket)),
    );
  }

  IconData _categoryIcon(TicketCategory category) {
    switch (category) {
      case TicketCategory.concert:   return Icons.music_note;
      case TicketCategory.sport:     return Icons.sports_soccer;
      case TicketCategory.cinema:    return Icons.movie_outlined;
      case TicketCategory.event:     return Icons.celebration;
      case TicketCategory.transport: return Icons.directions_bus;
    }
  }
}
