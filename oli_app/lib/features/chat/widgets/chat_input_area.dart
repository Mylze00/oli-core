import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/oli_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

const _maxRecordingDuration = Duration(minutes: 5);
const _minRecordingDuration = Duration(milliseconds: 800);
const _cancelDragDistance = -80.0;
const _lockDragDistance = -70.0;
const _recordingSignalEverySeconds = 3;
const _holdHint = 'Maintenez le bouton pour enregistrer un vocal';
const _amplitudeInterval = Duration(milliseconds: 100);
const _waveformBars = 40;
const _silenceDb = -50.0;

/// Un vocal prêt à être envoyé.
class VoiceRecording {
  final String path;
  final String fileName;
  final String mimeType;
  final Duration duration;

  /// Volumes de 0 à 100, pour dessiner l'onde du vocal.
  final List<int> waveform;

  const VoiceRecording({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.duration,
    this.waveform = const [],
  });
}

class _VoiceFormat {
  final AudioEncoder encoder;
  final String extension;
  final String mimeType;

  const _VoiceFormat(this.encoder, this.extension, this.mimeType);
}

const _voiceFormats = [
  _VoiceFormat(AudioEncoder.aacLc, 'm4a', 'audio/mp4'),
  _VoiceFormat(AudioEncoder.opus, 'webm', 'audio/webm'),
];

enum _VoiceState { idle, holding, locked, review }

class ChatInputArea extends StatefulWidget {
  final Function(String) onSendMessage;
  final void Function(VoiceRecording recording)? onVoiceRecorded;
  final VoidCallback onShowTools;
  final Function(bool)? onTyping;
  final void Function(bool isRecording)? onRecording;

  const ChatInputArea({
    super.key,
    required this.onSendMessage,
    required this.onShowTools,
    this.onVoiceRecorded,
    this.onTyping,
    this.onRecording,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _reviewPlayer = AudioPlayer();
  _VoiceState _voiceState = _VoiceState.idle;
  _VoiceFormat? _voiceFormat;
  bool _isStarting = false;
  bool _isPressing = false;
  bool _isReviewPlaying = false;
  double _dragOffset = 0.0;
  DateTime? _startTime;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  String? _reviewPath;
  final List<double> _levelsDb = [];
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _reviewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isReviewPlaying = state == PlayerState.playing);
    });
  }

  void _onTextChanged() {
    setState(() {}); // Refresh for icon change

    if (widget.onTyping != null) {
      widget.onTyping!(_controller.text.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _animController.dispose();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    if (_voiceState == _VoiceState.holding || _voiceState == _VoiceState.locked) {
      widget.onRecording?.call(false);
    }
    _audioRecorder.dispose();
    _reviewPlayer.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  void _showHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  // --- AUDIO RECORDING ---

  /// Tous les navigateurs n'enregistrent pas le même format.
  Future<_VoiceFormat?> _chooseFormat() async {
    if (_voiceFormat != null) return _voiceFormat;
    for (final format in _voiceFormats) {
      if (await _audioRecorder.isEncoderSupported(format.encoder)) {
        return _voiceFormat = format;
      }
    }
    return null;
  }

  Future<void> _startRecording() async {
    if (_isStarting || _voiceState != _VoiceState.idle) return;
    _isStarting = true;
    _isPressing = true;

    try {
      if (!await _audioRecorder.hasPermission()) {
        _showHint("Autorisez l'accès au micro pour enregistrer un vocal");
        return;
      }

      // La demande d'autorisation interrompt l'appui : ne jamais enregistrer sans doigt posé
      if (!_isPressing) {
        _showHint(_holdHint);
        return;
      }

      final format = await _chooseFormat();
      if (format == null) {
        _showHint('Cet appareil ne permet pas d\'enregistrer un vocal');
        return;
      }

      String path = '';
      if (!kIsWeb) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        path = '${appDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.${format.extension}';
      }

      await _audioRecorder.start(RecordConfig(encoder: format.encoder), path: path);

      if (!_isPressing) {
        await _audioRecorder.cancel();
        return;
      }
      if (!mounted) return;

      _levelsDb.clear();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(_amplitudeInterval)
          .listen((amplitude) => _levelsDb.add(amplitude.current));

      HapticFeedback.mediumImpact();
      setState(() {
        _voiceState = _VoiceState.holding;
        _startTime = DateTime.now();
        _recordDuration = Duration.zero;
        _dragOffset = 0.0;
      });
      widget.onRecording?.call(true);

      _timer = Timer.periodic(const Duration(seconds: 1), _onRecordingTick);
      _animController.forward();
    } catch (e) {
      debugPrint("Error starting record: $e");
      _showHint("Impossible de démarrer l'enregistrement");
    } finally {
      _isStarting = false;
    }
  }

  void _onRecordingTick(Timer timer) {
    if (!mounted) return;
    final elapsed = DateTime.now().difference(_startTime!);
    setState(() => _recordDuration = elapsed);

    if (timer.tick % _recordingSignalEverySeconds == 0) widget.onRecording?.call(true);

    if (elapsed >= _maxRecordingDuration) {
      _showHint('Durée maximale de 5 minutes atteinte');
      if (_voiceState == _VoiceState.locked) {
        _stopToReview();
      } else {
        _sendHeldRecording();
      }
    }
  }

  Duration get _elapsed => _startTime == null ? Duration.zero : DateTime.now().difference(_startTime!);

  /// Réduit les volumes relevés à quelques barres, de 0 (silence) à 100.
  List<int> _buildWaveform() {
    if (_levelsDb.isEmpty) return const [];
    return List.generate(_waveformBars, (i) {
      final start = (i * _levelsDb.length / _waveformBars).floor();
      final end = math.max(start + 1, ((i + 1) * _levelsDb.length / _waveformBars).floor());
      final peak = _levelsDb.sublist(start, math.min(end, _levelsDb.length)).reduce(math.max);
      return (((peak - _silenceDb) / -_silenceDb).clamp(0.05, 1.0) * 100).round();
    });
  }

  void _resetRecordingUi() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _timer?.cancel();
    _animController.reverse();
    widget.onRecording?.call(false);
  }

  void _emitRecording(String path, Duration duration) {
    final format = _voiceFormat;
    if (format == null) return;
    widget.onVoiceRecorded?.call(VoiceRecording(
      path: path,
      fileName: 'audio_message.${format.extension}',
      mimeType: format.mimeType,
      duration: duration,
      waveform: _buildWaveform(),
    ));
  }

  Future<void> _sendHeldRecording() async {
    if (_voiceState != _VoiceState.holding) return;
    final duration = _elapsed;
    _resetRecordingUi();
    setState(() {
      _voiceState = _VoiceState.idle;
      _dragOffset = 0.0;
    });

    if (duration < _minRecordingDuration) {
      await _audioRecorder.cancel();
      _showHint(_holdHint);
      return;
    }

    final path = await _audioRecorder.stop();
    if (path != null) _emitRecording(path, duration);
  }

  Future<void> _discardRecording() async {
    _resetRecordingUi();
    setState(() {
      _voiceState = _VoiceState.idle;
      _dragOffset = 0.0;
    });
    await _audioRecorder.cancel();
  }

  void _lockRecording() {
    HapticFeedback.mediumImpact();
    _animController.reverse();
    setState(() {
      _voiceState = _VoiceState.locked;
      _dragOffset = 0.0;
    });
  }

  Future<void> _stopToReview() async {
    _recordDuration = _elapsed;
    _resetRecordingUi();
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() {
      _reviewPath = path;
      _voiceState = path == null ? _VoiceState.idle : _VoiceState.review;
    });
  }

  Future<void> _toggleReviewPlayback() async {
    if (_isReviewPlaying) {
      await _reviewPlayer.pause();
      return;
    }
    final path = _reviewPath;
    if (path == null) return;
    await _reviewPlayer.play(kIsWeb ? UrlSource(path) : DeviceFileSource(path));
  }

  Future<void> _closeReview({required bool send}) async {
    await _reviewPlayer.stop();
    final path = _reviewPath;
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.idle;
      _reviewPath = null;
    });
    if (path == null) return;

    if (send) {
      _emitRecording(path, _recordDuration);
    } else if (!kIsWeb) {
      File(path).delete().ignore();
    }
  }

  void _onPressMove(LongPressMoveUpdateDetails details) {
    if (_voiceState != _VoiceState.holding) return;
    if (details.offsetFromOrigin.dy < _lockDragDistance) {
      _lockRecording();
      return;
    }
    setState(() => _dragOffset = details.offsetFromOrigin.dx);
  }

  void _onPressEnd() {
    _isPressing = false;
    if (_voiceState != _VoiceState.holding) return;
    if (_dragOffset < _cancelDragDistance) {
      _discardRecording();
    } else {
      _sendHeldRecording();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasText = _controller.text.isNotEmpty;
    final bool isIdle = _voiceState == _VoiceState.idle;
    final bool isHolding = _voiceState == _VoiceState.holding;
    final bool isCancelling = _dragOffset < _cancelDragDistance;

    final isDark = theme.brightness == Brightness.dark;
    final fieldColor = isDark ? OliChatDarkColors.receivedBubble : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? OliChatDarkColors.bar : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (isIdle)
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: theme.primaryColor, size: 28),
                onPressed: widget.onShowTools,
              ),

            Expanded(
              child: isIdle
                  ? Container(
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    )
                  : Container(
                      padding: EdgeInsets.symmetric(horizontal: isHolding ? 16 : 4),
                      height: 50,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: isHolding
                          ? _buildHoldingContent(isCancelling)
                          : _buildLockedOrReviewContent(theme),
                    ),
            ),

            if (isIdle || isHolding) const SizedBox(width: 8),

            if (hasText && isIdle)
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _handleSend,
                  constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  padding: EdgeInsets.zero,
                ),
              )
            else if (isIdle || isHolding)
              Semantics(
                button: true,
                label: 'Maintenir pour enregistrer un vocal',
                child: GestureDetector(
                  onTap: () => _showHint(_holdHint),
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressMoveUpdate: _onPressMove,
                  onLongPressEnd: (_) => _onPressEnd(),
                  onLongPressCancel: _onPressEnd,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isHolding ? (isCancelling ? Colors.red : Colors.redAccent) : theme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: isHolding
                            ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)]
                            : [],
                      ),
                      child: Icon(
                        isHolding && isCancelling ? Icons.delete : Icons.mic,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingContent(bool isCancelling) {
    return Row(
      children: [
        const Icon(Icons.mic, color: Colors.red, size: 24),
        const SizedBox(width: 10),
        Text(_formatDuration(_recordDuration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isCancelling ? 'Relâcher pour annuler' : '← Annuler   ↑ Verrouiller',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isCancelling ? Colors.red : Colors.grey, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedOrReviewContent(ThemeData theme) {
    final isReview = _voiceState == _VoiceState.review;
    return Row(
      children: [
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: isReview ? () => _closeReview(send: false) : _discardRecording,
        ),
        if (isReview)
          IconButton(
            tooltip: _isReviewPlaying ? 'Mettre en pause' : 'Réécouter',
            icon: Icon(_isReviewPlaying ? Icons.pause : Icons.play_arrow, color: theme.primaryColor),
            onPressed: _toggleReviewPlayback,
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.mic, color: Colors.red, size: 22),
          ),
        Text(_formatDuration(_recordDuration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        if (isReview)
          IconButton(
            tooltip: 'Envoyer',
            icon: Icon(Icons.send, color: theme.primaryColor),
            onPressed: () => _closeReview(send: true),
          )
        else
          IconButton(
            tooltip: "Arrêter l'enregistrement",
            icon: Icon(Icons.stop_circle, color: theme.primaryColor, size: 30),
            onPressed: _stopToReview,
          ),
      ],
    );
  }
}
