import 'package:flutter/material.dart';
import '../data/mock_tickets.dart';
import '../models/ticket_model.dart';
import '../widgets/ticket_widget.dart';
import 'ticket_detail_page.dart';

class OTicketPage extends StatefulWidget {
  const OTicketPage({super.key});

  @override
  State<OTicketPage> createState() => _OTicketPageState();
}

class _OTicketPageState extends State<OTicketPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTicketIndex = 0;

  List<OTicket> get _myTickets  => mockTickets;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyTickets(),
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

  // ── Onglet Explorer ──
  Widget _buildExplore() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_outlined, color: Color(0xFF7C4DFF), size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Événements à venir',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Les événements seront bientôt disponibles\ndans votre ville.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, size: 18, color: Color(0xFF7C4DFF)),
            label: const Text(
              'Me notifier',
              style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7C4DFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

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
