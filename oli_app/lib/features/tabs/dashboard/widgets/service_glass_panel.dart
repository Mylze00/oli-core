import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers/services_provider.dart';
import '../../../../models/service_model.dart';

class ServiceGlassPanel extends ConsumerWidget {
  const ServiceGlassPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsyncValues = ref.watch(servicesProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        height: 520, // Agrandissement de la fenêtre de 30% (passage de 400 à ~520)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.black.withOpacity(0.50), // Stable dark background like Supermarket
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), // Supermarket blur
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.15)),
              ),
              child: Stack(
                children: [
                   // Close button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          "Services Publics & Paiements",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: servicesAsyncValues.when(
                            data: (services) {
                              if (services.isEmpty) {
                                return const Center(child: Text("Aucun service disponible", style: TextStyle(color: Colors.white)));
                              }
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 15, // Léger écart rajouté entre les lignes
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.95, // Ratio ajusté pour bien respirer
                                ),
                                itemCount: services.length,
                                itemBuilder: (context, index) {
                                  final service = services[index];
                                  return _buildDynamicServiceButton(service);
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                            error: (err, stack) => Center(child: Text('Erreur: $err', style: const TextStyle(color: Colors.white))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicServiceButton(ServiceModel service) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Cercle logo (Supermarket style) ───────────────
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 84, // Increased from 50 (approx +100% larger given padding)
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // Solid white background for logos to pop clearly
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Builder(builder: (context) {
                  final isWebUrl = service.logoUrl.startsWith('http');
                  final localAssetUrl = isWebUrl 
                      ? service.logoUrl 
                      : (service.logoUrl.startsWith('assets/') 
                          ? service.logoUrl 
                          : 'assets/images/services/${service.logoUrl.split('/').last}');
                          
                  return isWebUrl
                      ? Image.network(
                          localAssetUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.error_outline, color: Colors.grey),
                        )
                      : Image.asset(
                          localAssetUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.error_outline, color: Colors.grey),
                        );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Nom ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            service.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
        if (service.status == 'coming_soon')
           Container(
             margin: const EdgeInsets.only(top: 4),
             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
             decoration: BoxDecoration(
               color: Colors.orange,
               borderRadius: BorderRadius.circular(10),
             ),
             child: const Text(
               "Bientôt",
               style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
             ),
           )
      ],
    );
  }
}
