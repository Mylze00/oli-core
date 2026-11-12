import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/orders_provider.dart';

/// Suivi du livreur en direct : position, parcours depuis la prise en charge,
/// destination et contact. Actualisé toutes les 8 secondes.
class CourierTrackingPage extends ConsumerStatefulWidget {
  final int orderId;

  const CourierTrackingPage({super.key, required this.orderId});

  @override
  ConsumerState<CourierTrackingPage> createState() => _CourierTrackingPageState();
}

class _CourierTrackingPageState extends ConsumerState<CourierTrackingPage> {
  static const _kinshasa = LatLng(-4.3250, 15.3222);

  final _map = MapController();
  Timer? _poll;
  Map<String, dynamic>? _data;
  String? _error;
  bool _followCourier = true;
  bool _fittedOnce = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(orderServiceProvider).getCourier(widget.orderId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
      _moveCamera();
      // Commande livrée : plus rien à suivre
      if (data['status'] == 'delivered') _poll?.cancel();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  LatLng? _latLng(dynamic p) {
    if (p is! Map || p['lat'] == null || p['lng'] == null) return null;
    return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
  }

  LatLng? get _courier => _latLng(_data?['current']);
  LatLng? get _destination => _latLng(_data?['destination']);

  List<LatLng> get _path => ((_data?['path'] as List?) ?? [])
      .whereType<List>()
      .where((p) => p.length == 2)
      .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();

  /// Premier affichage : tout le parcours et la destination ; ensuite, la carte suit le livreur.
  void _moveCamera() {
    final courier = _courier;
    if (courier == null) return;
    try {
      if (!_fittedOnce) {
        final points = [..._path, courier, if (_destination != null) _destination!];
        if (points.length > 1) {
          _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(70)));
        } else {
          _map.move(courier, 16);
        }
        _fittedOnce = true;
      } else if (_followCourier) {
        _map.move(courier, _map.camera.zoom);
      }
    } catch (_) {
      // Carte pas encore prête : le prochain rafraîchissement replacera la caméra
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'assigned':
        return 'Le livreur va chercher votre colis';
      case 'picked_up':
      case 'in_transit':
        return 'Votre colis est en route';
      case 'delivered':
        return 'Colis livré';
      case 'waiting_deliverer':
        return 'Recherche d\'un livreur';
      default:
        return 'Suivi de la livraison';
    }
  }

  String _lastSeen() {
    final raw = (_data?['current'] as Map?)?['updated_at'];
    final at = raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
    if (at == null) return '';
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds < 60) return 'Position mise à jour à l\'instant';
    if (seconds < 3600) return 'Position mise à jour il y a ${seconds ~/ 60} min';
    return 'Dernière position il y a plus d\'une heure';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF3B8EF0) : const Color(0xFF1A5DE6);
    final courier = _courier;
    final destination = _destination;
    final path = _path;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: courier ?? destination ?? _kinshasa,
              initialZoom: courier != null ? 15 : 12,
              // L'acheteur déplace la carte : on arrête de suivre le livreur
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _followCourier) setState(() => _followCourier = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.oli.apprdc',
              ),
              if (path.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [...path, if (courier != null) courier],
                      strokeWidth: 5,
                      color: accent,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (path.isNotEmpty)
                    Marker(point: path.first, width: 18, height: 18, child: _dot(Colors.white, accent)),
                  if (destination != null)
                    Marker(point: destination, width: 44, height: 44, child: _pin(Icons.home_rounded, Colors.black)),
                  if (courier != null) Marker(point: courier, width: 56, height: 56, child: _courierMarker(accent)),
                ],
              ),
            ],
          ),

          // Retour
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _roundButton(Icons.arrow_back_rounded, () => Navigator.pop(context), isDark),
            ),
          ),

          // Recentrer sur le livreur
          if (!_followCourier && courier != null)
            Positioned(
              right: 16,
              bottom: 230,
              child: _roundButton(Icons.my_location_rounded, () {
                setState(() => _followCourier = true);
                _map.move(courier, 16);
              }, isDark),
            ),

          // Carte d'information
          Align(alignment: Alignment.bottomCenter, child: _buildInfoCard(isDark, accent)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, Color accent) {
    final card = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF111418);
    final secondary = isDark ? const Color(0xFF9A9AA0) : const Color(0xFF5F6673);
    final deliverer = _data?['deliverer'] as Map?;
    final phone = deliverer?['phone']?.toString();
    final avatar = deliverer?['avatar_url']?.toString();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusLabel(_data?['status']?.toString()),
              style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _error ??
                  (_courier == null
                      ? (_data == null ? 'Chargement du suivi…' : 'Le livreur n\'a pas encore partagé sa position')
                      : _lastSeen()),
              style: TextStyle(color: _error != null ? const Color(0xFFE5484D) : secondary, fontSize: 13),
            ),
            if (deliverer != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar == null || avatar.isEmpty ? Icon(Icons.two_wheeler_rounded, color: accent) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deliverer['name']?.toString() ?? 'Livreur Oli',
                          style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Livreur Oli${_data?['estimated_time'] != null ? ' · ${_data!['estimated_time']}' : ''}',
                          style: TextStyle(color: secondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty)
                    IconButton.filled(
                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                      style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      icon: const Icon(Icons.call_rounded),
                      tooltip: 'Appeler le livreur',
                    ),
                ],
              ),
            ],
            if ((_data?['destination'] as Map?)?['address'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.home_outlined, size: 18, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_data!['destination'] as Map)['address'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _courierMarker(Color accent) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.18)),
      ),
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
        ),
        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
      ),
    ],
  );

  Widget _pin(IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );

  Widget _dot(Color fill, Color border) => Container(
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: Border.all(color: border, width: 4),
    ),
  );

  Widget _roundButton(IconData icon, VoidCallback onTap, bool isDark) => Material(
    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    shape: const CircleBorder(),
    elevation: 4,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 46, height: 46, child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF111418))),
    ),
  );
}
