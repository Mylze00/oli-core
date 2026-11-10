import 'package:flutter/material.dart';
import '../models/caa_schedule.dart';
import '../widgets/oticket_font.dart';

const _pageBlue = Color(0xFF072561);
const _rowBlue = Color(0xFF051A45);
const _buyColor = Color(0xFF7C4DFF);
const _flightRed = Color(0xFFE5121C);

/// Horaires des vols CAA, jour par jour.
class CaaSchedulePage extends StatefulWidget {
  const CaaSchedulePage({super.key});

  @override
  State<CaaSchedulePage> createState() => _CaaSchedulePageState();
}

class _CaaSchedulePageState extends State<CaaSchedulePage> {
  int _dayIndex = DateTime.now().weekday - 1;

  /// L'achat sera branché quand la vente de billets CAA sera configurée.
  void _buyTicket() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("L'achat de billets CAA sera bientôt disponible")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = caaSchedule[_dayIndex];
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
                'assets/images/logo_caa.png',
                height: 42,
                fit: BoxFit.contain,
                semanticLabel: 'Compagnie Africaine d\'Aviation',
              ),
            ),
            const SizedBox(height: 4),
            const Text('Programme du $caaScheduleDate', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                    '${day.label} · ${flights.length} vols',
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
            child: ListView.separated(
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
                    backgroundColor: _buyColor,
                    foregroundColor: Colors.white,
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
          for (var index = 0; index < caaSchedule.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == _dayIndex,
                label: caaSchedule[index].label,
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
                            caaSchedule[index].shortLabel,
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
  final CaaFlight flight;

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
                      text: 'Vol ${flight.number}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '  ·  ${flight.aircraft}'),
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
