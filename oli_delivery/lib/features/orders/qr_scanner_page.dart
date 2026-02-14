import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/delivery_service.dart';

/// Page de scan QR pour vérifier la livraison ou le retrait
class QrScannerPage extends ConsumerStatefulWidget {
  final int orderId;
  final bool isPickup;
  const QrScannerPage({super.key, required this.orderId, this.isPickup = false});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isVerifying = false;
  bool _hasScanned = false;
  String? _resultMessage;
  bool? _resultSuccess;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isVerifying || _hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    setState(() {
      _isVerifying = true;
      _hasScanned = true;
    });

    // Vibration feedback
    // HapticFeedback.mediumImpact();

    final bool success;
    if (widget.isPickup) {
      success = await ref.read(deliveryServiceProvider).verifyPickupCode(
        widget.orderId,
        code,
      );
    } else {
      success = await ref.read(deliveryServiceProvider).verifyDeliveryCode(
        widget.orderId,
        code,
      );
    }

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _resultSuccess = success;
        _resultMessage = success
            ? 'Livraison vérifiée avec succès !'
            : 'Code invalide. Réessayez.';
      });

      if (success) {
        // Retourner à la page précédente après un court délai
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  void _resetScan() {
    setState(() {
      _hasScanned = false;
      _resultMessage = null;
      _resultSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner — ${widget.isPickup ? 'Retrait' : 'Livraison'} #${widget.orderId}'),
        actions: [
          // Switch camera
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scan area
          _buildScanOverlay(),

          // Result banner
          if (_resultMessage != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildResultBanner(),
            ),

          // Verifying indicator
          if (_isVerifying)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Vérification en cours...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanSize = constraints.maxWidth * 0.7;
        final top = (constraints.maxHeight - scanSize) / 2 - 40;

        return Stack(
          children: [
            // Dark overlay
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black54,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    top: top,
                    left: (constraints.maxWidth - scanSize) / 2,
                    child: Container(
                      width: scanSize,
                      height: scanSize,
                      decoration: BoxDecoration(
                        color: Colors.red, // Any color works with srcOut
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scan area border
            Positioned(
              top: top,
              left: (constraints.maxWidth - scanSize) / 2,
              child: Container(
                width: scanSize,
                height: scanSize,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1E7DBA), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Instruction text
            Positioned(
              top: top + scanSize + 24,
              left: 0,
              right: 0,
              child: Text(
                'Scannez le QR code ${widget.isPickup ? 'du vendeur\npour confirmer le retrait' : 'du client\npour confirmer la livraison'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultBanner() {
    final isSuccess = _resultSuccess ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _resultMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            if (!isSuccess) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner à nouveau'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7DBA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
