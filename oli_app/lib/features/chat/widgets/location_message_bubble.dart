import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
    final double? lat = _parseCoordinate(metadata['lat']);
    final double? lng = _parseCoordinate(metadata['lng']);

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
            // OpenStreetMap via flutter_map
            AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mylze.oli',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Overlay "Ouvrir dans Maps"
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
    // Ouvrir dans OpenStreetMap au lieu de Google Maps
    final Uri osmUrl = Uri.parse("https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng");
    try {
      if (!await launchUrl(osmUrl, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch maps url");
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }
}
