import 'package:flutter/material.dart';
import '../models/flight_schedule.dart';
import '../widgets/oticket_colors.dart';
import '../widgets/oticket_font.dart';

const _pageBlue = Color(0xFF072561);
const _rowBlue = Color(0xFF051A45);
const _flightRed = Color(0xFFE5121C);

/// Horaires des vols d'une compagnie, jour par jour.
class FlightSchedulePage extends StatefulWidget {
  final AirlineSchedule schedule;

  const FlightSchedulePage({super.key, required this.schedule});

  @override
  State<FlightSchedulePage> createState() => _FlightSchedulePageState();
}

class _FlightSchedulePageState extends State<FlightSchedulePage> {
  int _dayIndex = DateTime.now().weekday - 1;

  /// L'achat sera branché quand la vente de billets sera configurée.
  void _buyTicket() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("L'achat de billets ${widget.schedule.name} sera bientôt disponible")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final day = schedule.days[_dayIndex];
    final flights = [...day.flights]
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return Scaffold(
      backgroundColor: _pageBlue,
      appBar: AppBar(
        backgroundColor: _pageBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 84,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Image.asset(
                schedule.logoAsset,
                height: 42,
                fit: BoxFit.contain,
                semanticLabel: schedule.logoLabel,
              ),
            ),
            const SizedBox(height: 4),
            Text(schedule.caption, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDaySelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${day.label} · ${flights.length} vol${flights.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (day.note != null)
                  Flexible(
                    child: Text(day.note!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: flights.isEmpty
                ? const Center(
                    child: Text('Aucun vol régulier ce jour', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: flights.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _FlightTile(flight: flights[index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _buyTicket,
                  icon: const Icon(Icons.flight_takeoff),
                  label: const Text('Acheter un billet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oticketDarkBlue,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    textStyle: const TextStyle(
                      fontFamily: OTicketFont.family,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 12),
          for (var index = 0; index < widget.schedule.days.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == _dayIndex,
                label: widget.schedule.days[index].label,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _dayIndex = index),
                    child: Center(
                      child: Container(
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == _dayIndex ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.schedule.days[index].shortLabel,
                            style: TextStyle(
                              color: index == _dayIndex ? _pageBlue : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _FlightTile extends StatelessWidget {
  final FlightLeg flight;

  const _FlightTile({required this.flight});

  Widget _buildStop(String time, String city, CrossAxisAlignment alignment, TextAlign textAlign) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(
          city,
          textAlign: textAlign,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _rowBlue, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  children: [
                    TextSpan(
                      text: flight.number == null ? 'Vol régulier' : 'Vol ${flight.number}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (flight.aircraft != null) TextSpan(text: '  ·  ${flight.aircraft}'),
                  ],
                )),
              ),
              if (flight.isInternational)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _flightRed, borderRadius: BorderRadius.circular(5)),
                  child: const Text('International', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStop(flight.departureTime, flight.departure, CrossAxisAlignment.start, TextAlign.start),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    const Icon(Icons.flight, color: Colors.white, size: 18),
                    const SizedBox(height: 2),
                    Text(
                      flight.blockTime,
                      semanticsLabel: 'Durée ${flight.blockTime}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildStop(flight.arrivalTime, flight.arrival, CrossAxisAlignment.end, TextAlign.end),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
