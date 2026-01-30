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
        height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1557683316-973673baf926'),
            fit: BoxFit.cover,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.2)),
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
                        const SizedBox(height: 20),
                        const Text(
                          "Services Publics & Paiements",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                  mainAxisSpacing: 15,
                                  crossAxisSpacing: 15,
                                  childAspectRatio: 0.9,
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
    // Parse color string '#RRGGBB' to Color
    Color bgColor = Colors.white.withOpacity(0.2);
    try {
      if (service.colorHex.startsWith('#')) {
        String hex = service.colorHex.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex'; // Add Opacity
        // bgColor = Color(int.parse(hex, radix: 16)).withOpacity(0.3); // Optionnel: utiliser la couleur en bg
      }
    } catch (e) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), // Base background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Image.network(
              service.logoUrl,
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.error_outline, color: Colors.white),
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              service.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
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
      ),
    );
  }
}
