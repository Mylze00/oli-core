import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallQuality { good, poor }

/// Juge la qualité de l'appel à partir des statistiques WebRTC relevées à intervalle régulier.
class CallQualityMonitor {
  static const _maxPacketLoss = 0.08;
  static const _maxRoundTripSeconds = 0.6;
  static const _maxJitterSeconds = 0.1;

  /// Plusieurs relevés de suite évitent un message qui clignote.
  static const _samplesBeforeChange = 2;

  double? _lastReceived;
  double _lastLost = 0;
  int _streak = 0;
  CallQuality _quality = CallQuality.good;

  CallQuality get quality => _quality;

  static double? _number(Object? value) => value == null ? null : double.tryParse('$value');

  CallQuality update(List<StatsReport> reports) {
    final isPoor = _isPoor(reports);
    final observed = isPoor ? CallQuality.poor : CallQuality.good;

    if (observed == _quality) {
      _streak = 0;
      return _quality;
    }
    _streak++;
    if (_streak >= _samplesBeforeChange) {
      _quality = observed;
      _streak = 0;
    }
    return _quality;
  }

  bool _isPoor(List<StatsReport> reports) {
    var isPoor = false;

    for (final report in reports) {
      final values = report.values;
      if (report.type == 'candidate-pair' && values['state'] == 'succeeded' && '${values['nominated']}' == 'true') {
        final roundTrip = _number(values['currentRoundTripTime']);
        if (roundTrip != null && roundTrip > _maxRoundTripSeconds) isPoor = true;
      }

      if (report.type == 'inbound-rtp' && (values['kind'] ?? values['mediaType']) == 'audio') {
        final jitter = _number(values['jitter']);
        if (jitter != null && jitter > _maxJitterSeconds) isPoor = true;

        final received = _number(values['packetsReceived']);
        final lost = _number(values['packetsLost']) ?? 0;
        if (received == null) continue;

        final previous = _lastReceived;
        if (previous != null) {
          final receivedNow = received - previous;
          final lostNow = lost - _lastLost;
          final total = receivedNow + lostNow;
          if (receivedNow <= 0 || (total > 0 && lostNow / total > _maxPacketLoss)) isPoor = true;
        }
        _lastReceived = received;
        _lastLost = lost;
      }
    }
    return isPoor;
  }
}
