import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../widgets/ticket_widget.dart';

class TicketDetailPage extends StatelessWidget {
  final OTicket ticket;

  const TicketDetailPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Détail du Billet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Partage bientôt disponible'),
                  backgroundColor: Color(0xFF1A1A2E),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Hero(
                  tag: 'ticket-${ticket.id}',
                  child: TicketWidget(ticket: ticket),
                ),
              ),
            ),
          ),

          // ── Bouton d'action ──
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: ticket.isValid ? () {} : null,
                icon: Icon(
                  ticket.isValid ? Icons.qr_code_scanner : Icons.block,
                  size: 20,
                ),
                label: Text(
                  ticket.isValid
                      ? 'Présenter à l\'entrée'
                      : 'Billet ${ticket.statusLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ticket.isValid ? ticket.color : Colors.grey[800],
                  foregroundColor: ticket.isValid ? Colors.black : Colors.white54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: ticket.isValid ? 6 : 0,
                  shadowColor: ticket.color.withOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
