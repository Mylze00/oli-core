import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_model.dart';
import '../providers/oticket_provider.dart';
import 'organizer_scan_page.dart';
import '../widgets/oticket_font.dart';
import '../widgets/ticket_widget.dart';
import 'event_detail_page.dart';
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
  int _currentEventIndex = 0;
  final PageController _eventsController = PageController(viewportFraction: 0.85);

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
    _eventsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(myTicketsProvider);
    _myTickets = ticketsAsync.valueOrNull ?? const [];

    return OTicketFont(
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A18),
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExplore(),
            ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
              error: (_, __) => _buildLoadError(),
              data: (_) => _buildMyTickets(),
            ),
          ],
        ),
      ),
    );
  }

  /// Accès au contrôle des entrées, visible seulement pour un organisateur.
  Widget? _buildScanAction() {
    final events = ref.watch(organizerEventsProvider).valueOrNull ?? const [];
    if (events.isEmpty) return null;
    return IconButton(
      tooltip: 'Contrôler les entrées',
      icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7C4DFF)),
      onPressed: () => _chooseEventToScan(events),
    );
  }

  void _chooseEventToScan(List<OrganizerEvent> events) {
    if (events.length == 1) {
      _openScanner(events.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14142B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Quel événement contrôler ?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...events.map((e) => ListTile(
                  title: Text(e.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${e.date} · ${e.checkedIn}/${e.sold} entrée(s)',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openScanner(e);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openScanner(OrganizerEvent e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTicketFont(
          child: OrganizerScanPage(eventId: e.id, eventTitle: e.title),
        ),
      ),
    ).then((_) => ref.invalidate(organizerEventsProvider));
  }

  AppBar _buildAppBar() {
    final scanAction = _buildScanAction();
    return AppBar(
      backgroundColor: const Color(0xFF0A0A18),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: scanAction == null ? null : [scanAction],
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
        labelStyle: const TextStyle(
          fontFamily: OTicketFont.family,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Explorer'),
          Tab(text: 'Mes Billets'),
        ],
      ),
    );
  }

  // ── Onglet Mes Billets ──
  Widget _buildMyTickets() {
    if (_myTickets.isEmpty) return _buildEmptyState();

    return SingleChildScrollView(
      child: Column(
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
      ),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${events.length} événement${events.length > 1 ? 's' : ''} à venir',
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 480,
                  child: PageView.builder(
                    controller: _eventsController,
                    itemCount: events.length,
                    onPageChanged: (i) => setState(() => _currentEventIndex = i),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => _openEvent(events[i]),
                      child: AnimatedScale(
                        scale: _currentEventIndex == i ? 1.0 : 0.92,
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _buildEventCard(events[i]),
                        ),
                      ),
                    ),
                  ),
                ),
                if (events.length > 1) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      events.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentEventIndex == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentEventIndex == i
                              ? const Color(0xFF7C4DFF)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Événement au format billet : le bas affiche le prix à la place du QR code,
  /// qui n'existe qu'après l'achat.
  Widget _buildEventCard(OEvent e) {
    final onSale = e.typeCount > 0;

    return TicketWidget(
      ticket: e.toPreviewTicket(),
      topFlex: 72,
      footer: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            onSale ? 'À PARTIR DE' : 'BILLETTERIE',
            style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            onSale ? '${e.minPriceFC.toStringAsFixed(0)} FC' : 'Bientôt en vente',
            style: const TextStyle(
                color: Color(0xFFFFD700), fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () => _openEvent(e),
              style: ElevatedButton.styleFrom(
                backgroundColor: e.soldOut ? Colors.grey[800] : const Color(0xFF7C4DFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                e.soldOut ? 'Complet' : 'Voir les billets',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre la page de l'événement et bascule sur « Mes Billets » après un achat.
  Future<void> _openEvent(OEvent e) async {
    final purchased = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OTicketFont(child: EventDetailPage(event: e))),
    );
    if (purchased != true || !mounted) return;
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Billet acheté. Retrouvez-le dans « Mes Billets ».'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
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
      MaterialPageRoute(builder: (_) => OTicketFont(child: TicketDetailPage(ticket: ticket))),
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
