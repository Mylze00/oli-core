import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMessageBubble extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;

  const LocationMessageBubble({
    super.key,
    required this.metadata,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // Parse lat/lng from metadata. Ensure we handle strings or doubles.
    final double? lat = _parseCoordinate(metadata['lat']);
    final double? lng = _parseCoordinate(metadata['lng']);
    
    // Fallback if coordinates are missing (should not happen if logic is correct)
    if (lat == null || lng == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.grey),
            SizedBox(width: 8),
            Text("Position invalide"),
          ],
        ),
      );
    }

    final LatLng position = LatLng(lat, lng);

    return GestureDetector(
      onTap: () => _launchMaps(lat, lng),
      child: Container(
        width: 240,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Google Map in Lite Mode (Static snapshot feel, optimized for lists)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: position,
                zoom: 16, // Zoom légèrement plus rapproché
              ),
              markers: {
                Marker(
                  markerId: MarkerId('pos_${lat}_$lng'),
                  position: position,
                  // infoWindow: const InfoWindow(title: "Position partagée"), // Pas toujours visible en LiteMode
                ),
              },
              liteModeEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              onTap: (_) => _launchMaps(lat, lng), // Catch map taps
            ),
            // Overlay for "Open in Maps" hint
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Ouvrir dans Maps",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new, color: Colors.white, size: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch maps url");
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }
}
