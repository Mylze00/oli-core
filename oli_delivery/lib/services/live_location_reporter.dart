import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/api_config.dart';
import '../core/providers/dio_provider.dart';
import 'location_service.dart';

final liveLocationReporterProvider = Provider<LiveLocationReporter>((ref) {
  final reporter = LiveLocationReporter(dio: ref.watch(dioProvider));
  ref.onDispose(reporter.stop);
  return reporter;
});

/// Envoie la position du livreur toutes les 15 secondes pendant ses courses en cours,
/// pour que l'acheteur suive son parcours en direct. Rien n'est envoyé sans course active.
class LiveLocationReporter {
  final Dio _dio;
  Timer? _timer;
  bool _busy = false;

  LiveLocationReporter({required Dio dio}) : _dio = dio;

  static const _activeStatuses = {'assigned', 'picked_up', 'in_transit'};

  void start() {
    if (_timer != null) return;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final response = await _dio.get(ApiConfig.deliveryMyTasks);
      final tasks = (response.data as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((t) => _activeStatuses.contains(t['status']))
          .toList();
      if (tasks.isEmpty) return;

      final position = await LocationService.getCurrentPosition();
      if (position == null) return;

      for (final task in tasks) {
        await _dio.post(
          ApiConfig.deliveryLocation(task['id']),
          data: {'lat': position.latitude, 'lng': position.longitude},
        );
      }
    } catch (e) {
      debugPrint('⚠️ Position livreur non envoyée : $e');
    } finally {
      _busy = false;
    }
  }
}
