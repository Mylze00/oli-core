import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../config/api_config.dart';
import '../../../core/theme/oli_glass.dart';
import '../../../core/theme/oli_colors.dart';
import '../../../../widgets/auto_refresh_avatar.dart';

const _waveformHeight = 26.0;
const _waveformBars = 34;
const _playButtonSize = 36.0;
const _avatarSize = 48.0;
const _micBadgeSize = 20.0;
const _thumbRadius = 6.0;
const _voiceBubbleWidth = 264.0;

/// Vert franc sur la bulle bleue : l'expéditeur voit que son vocal a été écouté.
const _listenedOnBlue = Color(0xFF7CFFB2);

String _formatDuration(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

Color _audioColor(BuildContext context, bool isMe) =>
    isMe || Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

/// Les anciens vocaux n'ont pas d'onde enregistrée : une forme stable est dérivée de leur adresse.
List<double> _fallbackWaveform(String seed) {
  final random = math.Random(seed.hashCode);
  return List.generate(_waveformBars, (_) => 0.25 + random.nextDouble() * 0.6);
}

List<double> _resample(List<double> levels) {
  if (levels.isEmpty) return levels;
  return List.generate(_waveformBars, (i) => levels[(i * levels.length / _waveformBars).floor()]);
}

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
      width: 210,
      height: 44,
      child: Row(
        children: [
          SizedBox.square(
            dimension: _playButtonSize,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: CircularProgressIndicator(
                value: progress < 1 ? progress : null,
                strokeWidth: 2.5,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('Envoi du vocal', style: TextStyle(color: color, fontSize: 13)),
          const Spacer(),
          Text(_formatDuration(Duration(milliseconds: durationMs)),
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }
}

class AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  /// Durée enregistrée à l'envoi : les anciens vocaux n'en ont pas.
  final int? durationMs;

  /// Volumes de 0 à 100 relevés pendant l'enregistrement.
  final List<int>? waveform;

  /// Le destinataire a écouté le vocal.
  final bool isPlayed;

  /// Appelé à la première écoute par le destinataire.
  final VoidCallback? onFirstPlay;

  /// Heure et coches, placées dans la bande.
  final Widget? footer;

  /// Photo de l'auteur du vocal, affichée à gauche avec un badge micro.
  final String? avatarUrl;

  const AudioMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.durationMs,
    this.waveform,
    this.isPlayed = false,
    this.onFirstPlay,
    this.footer,
    this.avatarUrl,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  /// Un seul vocal se joue à la fois.
  static _AudioMessageBubbleState? _playing;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _hasSource = false;
  bool _hasReportedPlay = false;
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

  List<double> get _levels {
    final recorded = widget.waveform;
    if (recorded == null || recorded.isEmpty) return _fallbackWaveform(widget.audioUrl);
    return _resample(recorded.map((v) => (v / 100).clamp(0.08, 1.0)).toList());
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
      // « Écouté » seulement quand le son joue vraiment, pas au simple appui
      if (state == PlayerState.playing && !widget.isMe && !widget.isPlayed && !_hasReportedPlay) {
        _hasReportedPlay = true;
        widget.onFirstPlay?.call();
      }
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

  Future<void> _seekToFraction(double fraction) async {
    final total = _totalDuration;
    if (total <= Duration.zero) return;
    final target = Duration(milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round());
    setState(() => _position = target);
    await _ensureSource();
    await _audioPlayer.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _audioColor(context, widget.isMe);
    final total = _totalDuration;
    final progress = total.inMilliseconds > 0 ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final label = _isPlaying || _position > Duration.zero ? _position : total;
    final unheardBlue = isDark ? OliPalette.blueOnDark : OliPalette.blue;

    // Expéditeur : les barres passent au vert une fois écouté. Destinataire : bleu tant qu'il n'a pas écouté.
    final idleBarColor = widget.isMe
        ? (widget.isPlayed ? _listenedOnBlue : Colors.white.withOpacity(0.45))
        : (widget.isPlayed ? color.withOpacity(0.35) : unheardBlue);
    final accent = widget.isMe
        ? (widget.isPlayed ? _listenedOnBlue : Colors.white)
        : (widget.isPlayed ? color.withOpacity(0.6) : unheardBlue);
    final bubbleColor = widget.isMe
        ? theme.primaryColor
        : (isDark ? OliChatDarkColors.receivedBubble : Colors.white);

    return SizedBox(
      width: _voiceBubbleWidth,
      child: Row(
        children: [
          _buildAvatar(accent, bubbleColor),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _isPlaying ? 'Mettre en pause' : 'Écouter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: _playButtonSize, height: _playButtonSize),
            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: color, size: _playButtonSize),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seekToFraction(d.localPosition.dx / constraints.maxWidth),
                    onHorizontalDragUpdate: (d) => _seekToFraction(d.localPosition.dx / constraints.maxWidth),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, _waveformHeight),
                      painter: _WaveformPainter(
                        levels: _levels,
                        progress: progress,
                        playedColor: color,
                        idleColor: idleBarColor,
                        thumbColor: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      total > Duration.zero || _isPlaying ? _formatDuration(label) : 'Vocal',
                      style: TextStyle(color: color.withOpacity(0.75), fontSize: 11),
                    ),
                    const Spacer(),
                    if (widget.footer != null) widget.footer!,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Photo de l'auteur et badge micro, coloré selon l'écoute.
  Widget _buildAvatar(Color micColor, Color bubbleColor) {
    return SizedBox.square(
      dimension: _avatarSize + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: AutoRefreshAvatar(avatarUrl: widget.avatarUrl, size: _avatarSize),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: _micBadgeSize,
              height: _micBadgeSize,
              decoration: BoxDecoration(color: bubbleColor, shape: BoxShape.circle),
              child: Icon(Icons.mic, size: 15, color: micColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barres arrondies : la partie déjà jouée prend la couleur du texte.
class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final double progress;
  final Color playedColor;
  final Color idleColor;
  final Color thumbColor;

  const _WaveformPainter({
    required this.levels,
    required this.progress,
    required this.playedColor,
    required this.idleColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    // Les barres laissent la place du curseur aux deux extrémités
    final barsWidth = size.width - _thumbRadius * 2;
    final slot = barsWidth / levels.length;
    final barWidth = math.max(2.0, slot * 0.55);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < levels.length; i++) {
      final x = _thumbRadius + slot * i + slot / 2;
      final height = math.max(barWidth, size.height * levels[i]);
      paint
        ..color = (i + 0.5) / levels.length <= progress ? playedColor : idleColor
        ..strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2 + barWidth / 2),
        Offset(x, (size.height + height) / 2 - barWidth / 2),
        paint,
      );
    }

    // Curseur rond : position de lecture, à glisser pour avancer
    canvas.drawCircle(
      Offset(_thumbRadius + barsWidth * progress, size.height / 2),
      _thumbRadius,
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.thumbColor != thumbColor ||
      oldDelegate.levels != levels;
}
