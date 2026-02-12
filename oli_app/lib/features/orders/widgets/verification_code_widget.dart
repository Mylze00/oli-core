import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget pour afficher un code de vérification avec QR code simulé
/// Utilisé pour le pickup_code (vendeur → livreur) et delivery_code (acheteur → livreur)
class VerificationCodeWidget extends StatelessWidget {
  final String code;
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData icon;

  const VerificationCodeWidget({
    super.key,
    required this.code,
    required this.title,
    this.subtitle = '',
    this.accentColor = Colors.blue,
    this.icon = Icons.qr_code_2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),

          // QR Code area (visual representation)
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _buildQRPattern(code),
            ),
          ),

          const SizedBox(height: 16),

          // Code en grand
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code $code copié !'),
                  backgroundColor: accentColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.copy, color: accentColor.withOpacity(0.6), size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Appuyez pour copier le code',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Génère un pattern visuel QR simplifié basé sur le code
  Widget _buildQRPattern(String code) {
    // Pattern de grille basé sur le hash du code
    final hash = code.codeUnits.fold<int>(0, (prev, c) => prev * 31 + c);
    const gridSize = 9;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(gridSize, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(gridSize, (col) {
              // Coins fixes (finder patterns style QR)
              final isCorner = (row < 3 && col < 3) ||
                               (row < 3 && col >= gridSize - 3) ||
                               (row >= gridSize - 3 && col < 3);
              
              // Pattern central basé sur le code
              final cellHash = (hash + row * gridSize + col) % 7;
              final isFilled = isCorner || cellHash < 3;

              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isFilled ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
