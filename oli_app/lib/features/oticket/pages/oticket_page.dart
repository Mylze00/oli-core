import 'package:oli_app/core/widgets/oli_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_model.dart';
import '../providers/oticket_provider.dart';
import '../models/caa_schedule.dart';
import '../models/flight_schedule.dart';
import '../models/kin_avia_schedule.dart';
import 'flight_schedule_page.dart';
import 'organizer_scan_page.dart';
import '../widgets/event_ticket_card.dart';
import '../widgets/oticket_font.dart';
import '../widgets/ticket_widget.dart';
import 'event_detail_page.dart';
import 'ticket_detail_page.dart';

/// Fond à motifs de la billetterie ; sa couleur unie sert le temps du chargement.
const _backgroundImage = 'assets/images/oticket_bg.png';
const _pageBlue = Color(0xFF051941);
/// Même bleu que la bande unie qui termine le visuel du fond.
const _hubBlue = Color(0xFF072561);
const _roundButtonColor = Color(0xFF0A0A18);
const _designPageWidth = 925.0;
const _headerHeight = 150.0;
const _hubHeightFactor = 0.6;
const _hubMinHeight = 150.0;
const _hubPartners = [caaAirlineSchedule, kinAviaSchedule];

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
  final PageController _eventsController = PageController();

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
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _pageBlue,
          image: DecorationImage(
            image: AssetImage(_backgroundImage),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildHeader(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExplore(),
            ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (_, __) => _buildLoadError(),
              data: (_) => _buildMyTickets(),
            ),
          ],
        ),
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
      icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: _roundButtonColor,
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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

  PreferredSizeWidget _buildHeader() {
    final scanAction = _buildScanAction();
    final topInset = MediaQuery.of(context).padding.top;
    return PreferredSize(
      preferredSize: Size.fromHeight(_headerHeight + topInset),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 15,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: _roundButtonColor,
                  fixedSize: const Size(36, 36),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            if (scanAction != null) Positioned(top: 14, right: 15, child: scanAction),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/logo_oli_ticket.png',
                  height: 66,
                  fit: BoxFit.contain,
                  semanticLabel: 'Oli Ticket',
                ),
              ),
            ),
            Positioned(top: 119, left: 0, right: 0, height: 31, child: _buildTabs()),
          ],
        ),
      ),
    );
  }

  /// Onglets de la maquette : trait continu, repère épais et libellés en dessous.
  Widget _buildTabs() {
    const firstCenter = 300 / _designPageWidth;
    const secondCenter = 693 / _designPageWidth;
    const indicatorWidth = 64.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final lineInset = width * 34 / _designPageWidth;

        Widget label(String text, double center, int index) => Positioned(
              top: 2,
              height: 26,
              left: width * center - 70,
              width: 140,
              child: TextButton(
                onPressed: () => _tabController.animateTo(index),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: OTicketFont.family,
                    fontSize: 12.5,
                  ),
                ),
              ),
            );

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: lineInset,
              right: lineInset,
              height: 2,
              child: const ColoredBox(color: Colors.white),
            ),
            AnimatedBuilder(
              animation: _tabController.animation!,
              builder: (context, _) {
                final center = firstCenter + (secondCenter - firstCenter) * _tabController.animation!.value;
                return Positioned(
                  top: 0,
                  left: width * center - indicatorWidth / 2,
                  width: indicatorWidth,
                  height: 5,
                  child: const ColoredBox(color: Colors.white),
                );
              },
            ),
            label('Explorer', firstCenter, 0),
            label('Mes billets', secondCenter, 1),
          ],
        );
      },
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
                        ? Colors.white
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
                    child: OliImage.network(
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final cardLeft = pageWidth * 83 / _designPageWidth;
        final cardRight = pageWidth * 79 / _designPageWidth;
        final cardHeight = EventTicketCard.heightFor(pageWidth - cardLeft - cardRight);
        final events = eventsAsync.valueOrNull ?? const <OEvent>[];
        const dotsHeight = 44.0;
        const cardTopSpacing = 7.0;
        const hubGap = 16.0;
        final countLineHeight = events.isEmpty ? 0.0 : 34.0;
        final spaceForHub = constraints.maxHeight - cardTopSpacing - countLineHeight - cardHeight - dotsHeight - hubGap;
        final hubHeight = (spaceForHub * _hubHeightFactor).clamp(_hubMinHeight, double.infinity);
        // La place libérée par le Hub est répartie autour de la carte
        final extraSpacing = ((spaceForHub - hubHeight) / 2).clamp(0.0, double.infinity);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(oticketEventsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: cardTopSpacing + extraSpacing),
                if (events.isNotEmpty)
                  SizedBox(
                    height: countLineHeight,
                    child: Padding(
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
                  ),
                SizedBox(
                  height: cardHeight,
                  child: eventsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (_, __) => _buildLoadError(),
                    data: (loaded) {
                      if (loaded.isEmpty) return _buildNoEvents();
                      return PageView.builder(
                        controller: _eventsController,
                        itemCount: loaded.length,
                        onPageChanged: (i) => setState(() => _currentEventIndex = i),
                        itemBuilder: (context, i) => Padding(
                          padding: EdgeInsets.only(left: cardLeft, right: cardRight),
                          child: GestureDetector(
                            onTap: () => _openEvent(loaded[i]),
                            child: _buildEventCard(loaded[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: dotsHeight, child: _buildEventDots(events.length)),
                SizedBox(height: hubGap + extraSpacing),
                _buildHub(hubHeight),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventDots(int count) {
    if (count < 2) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: _currentEventIndex == i ? const Color(0xFF03112D) : Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildHub(double height) {
    // Place de la barre Android en bas (0 quand elle est masquée) : le fond bleu
    // passe dessous, les logos restent au-dessus au lieu d'être recouverts.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      height: height + bottomInset,
      color: _hubBlue,
      padding: EdgeInsets.fromLTRB(23, 12, 23, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('Hub', style: TextStyle(color: Colors.white, fontSize: 17))),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final partner in _hubPartners) ...[
                _buildHubPartner(partner),
                const SizedBox(width: 28),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openFlightSchedule(AirlineSchedule schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OTicketFont(child: FlightSchedulePage(schedule: schedule))),
    );
  }

  Widget _buildHubPartner(AirlineSchedule schedule) {
    return Semantics(
      button: true,
      label: schedule.name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openFlightSchedule(schedule),
        child: Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(9),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Image.asset(schedule.logoAsset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// Événement à l'affiche : le bas de la carte présente le prix et l'accès aux billets.
  Widget _buildEventCard(OEvent e) {
    final onSale = e.typeCount > 0;
    return EventTicketCard(
      ticket: e.toPreviewTicket(),
      priceCaption: onSale ? 'À PARTIR DE' : 'BILLETTERIE',
      priceLabel: onSale ? '${e.minPriceFC.toStringAsFixed(0)} FC' : 'Bientôt en vente',
      buttonLabel: e.soldOut ? 'Complet' : 'Voir les billets',
      isDisabled: e.soldOut,
      onOpen: () => _openEvent(e),
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

  Widget _buildNoEvents() => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_outlined, color: Colors.white70, size: 48),
              SizedBox(height: 16),
              Text('Aucun événement pour le moment',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Revenez bientôt : de nouveaux événements\nseront publiés dans votre ville.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            ],
          ),
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
              child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
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
