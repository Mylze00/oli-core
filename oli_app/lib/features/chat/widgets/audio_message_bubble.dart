import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../config/api_config.dart';

String _formatDuration(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

Color _audioColor(BuildContext context, bool isMe) =>
    isMe || Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

/// Vocal en cours d'envoi, affiché dès la fin de l'enregistrement.
class AudioUploadingBubble extends StatelessWidget {
  final double progress;
  final int durationMs;
  final bool isMe;

  const AudioUploadingBubble({super.key, required this.progress, required this.durationMs, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = _audioColor(context, isMe);
    return SizedBox(
      width: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                value: progress < 1 ? progress : null,
                strokeWidth: 2.5,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Text('Envoi du vocal', style: TextStyle(color: color, fontSize: 13)),
            const Spacer(),
            Text(_formatDuration(Duration(milliseconds: durationMs)),
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  /// Durée enregistrée à l'envoi : les anciens vocaux n'en ont pas.
  final int? durationMs;

  const AudioMessageBubble({super.key, required this.audioUrl, required this.isMe, this.durationMs});

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  /// Un seul vocal se joue à la fois.
  static _AudioMessageBubbleState? _playing;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _hasSource = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  /// Un enregistrement WebM n'est pas lisible partout : Cloudinary fournit un MP3.
  String get _playbackUrl {
    final url = widget.audioUrl.startsWith('http') ? widget.audioUrl : '${ApiConfig.baseUrl}/${widget.audioUrl}';
    if (!url.contains('/upload/') || !url.endsWith('.webm')) return url;
    return url.replaceFirst('/upload/', '/upload/f_mp3/').replaceFirst(RegExp(r'\.webm$'), '.mp3');
  }

  Duration get _totalDuration =>
      _duration > Duration.zero ? _duration : Duration(milliseconds: widget.durationMs ?? 0);

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    if (_playing == this) _playing = null;
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ensureSource() async {
    if (_hasSource) return;
    await _audioPlayer.setSourceUrl(_playbackUrl);
    _hasSource = true;
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (_playing != this) await _playing?._audioPlayer.pause();
    _playing = this;
    await _ensureSource();
    await _audioPlayer.resume();
  }

  Future<void> _seek(double milliseconds) async {
    final target = Duration(milliseconds: milliseconds.round());
    setState(() => _position = target);
    await _ensureSource();
    await _audioPlayer.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final color = _audioColor(context, widget.isMe);
    final total = _totalDuration;
    final maxMs = math.max(total.inMilliseconds.toDouble(), 1.0);
    final label = _isPlaying || _position > Duration.zero ? _position : total;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: _isPlaying ? 'Mettre en pause' : 'Écouter',
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: color, size: 36),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2,
                    activeTrackColor: color.withOpacity(0.8),
                    inactiveTrackColor: color.withOpacity(0.3),
                    thumbColor: color,
                    overlayColor: color.withOpacity(0.1),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: _position.inMilliseconds.toDouble().clamp(0.0, maxMs),
                    onChanged: total > Duration.zero ? _seek : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    total > Duration.zero || _isPlaying ? _formatDuration(label) : 'Message vocal',
                    style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
