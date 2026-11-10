import '../widgets/oticket_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/oticket_provider.dart';

/// Contrôle des entrées : l'organisateur scanne le QR du billet.
///
/// Le serveur vérifie que l'utilisateur organise bien l'événement, que le
/// billet lui appartient et qu'il n'a pas déjà été utilisé.
class OrganizerScanPage extends ConsumerStatefulWidget {
  final int eventId;
  final String eventTitle;

  const OrganizerScanPage({super.key, required this.eventId, required this.eventTitle});

  @override
  ConsumerState<OrganizerScanPage> createState() => _OrganizerScanPageState();
}

class _OrganizerScanPageState extends ConsumerState<OrganizerScanPage> {
  bool _busy = false;
  int _checkedIn = 0;
  ScanOutcome? _last;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_busy) return;
    setState(() => _busy = true);

    final outcome = await validateTicket(ref, code, widget.eventId);
    if (!mounted) return;
    setState(() {
      _last = outcome;
      if (outcome.result == 'valid') _checkedIn++;
    });

    // Pause avant le scan suivant, pour laisser lire le résultat
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A18),
        foregroundColor: Colors.white,
        title: Text(widget.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_checkedIn entrée(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 44),
                          const SizedBox(height: 10),
                          const Text(
                            "Caméra indisponible. Autorisez l'accès, puis réessayez, "
                            'ou saisissez le code ci-dessous.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text('Détail : ${error.errorCode.name}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final v = b.rawValue;
                      if (v != null && v.isNotEmpty) {
                        _handleCode(v);
                        break;
                      }
                    }
                  },
                ),
                // Viseur
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          _buildResult(),
          _buildManualEntry(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final r = _last;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Présentez le QR code du billet devant la caméra.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final (color, icon) = switch (r.result) {
      'valid' => (const Color(0xFF22C55E), Icons.check_circle_rounded),
      'already_used' => (const Color(0xFFF59E0B), Icons.history_rounded),
      _ => (const Color(0xFFEF4444), Icons.cancel_rounded),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.message,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                if (r.detail != null)
                  Text(r.detail!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ou saisir le code du billet',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF14142B),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _handleCode(v.trim());
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: oticketDarkBlue),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) _handleCode(ctrl.text.trim());
            },
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
