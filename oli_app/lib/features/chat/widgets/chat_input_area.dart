import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/oli_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

const _maxRecordingDuration = Duration(minutes: 5);
const _minRecordingDuration = Duration(milliseconds: 800);
const _cancelDragDistance = -80.0;
const _lockDragDistance = -70.0;
const _recordingSignalEverySeconds = 3;
const _holdHint = 'Maintenez le bouton pour enregistrer un vocal';
const _amplitudeInterval = Duration(milliseconds: 100);
const _waveformBars = 40;
const _silenceDb = -50.0;
const _liveBarSlot = 4.5;
const _recorderButtonSize = 50.0;
const _recorderRed = Color(0xFFE5484D);
const _recorderGreen = Color(0xFF25D366);

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

enum _VoiceState { idle, holding, locked }

/// Une option du panneau de pièces jointes (galerie, caméra, position…).
class ChatAttachmentOption {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ChatAttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

const _attachmentColumns = 4;
const _panelAnimation = Duration(milliseconds: 240);
const _panelRadius = 30.0;
const _attachmentCircle = 66.0;

class ChatInputArea extends StatefulWidget {
  final Function(String) onSendMessage;
  final void Function(VoiceRecording recording)? onVoiceRecorded;
  /// Options affichées sous la barre quand on appuie sur le bouton +.
  final List<ChatAttachmentOption> attachments;
  final Function(bool)? onTyping;
  final void Function(bool isRecording)? onRecording;

  const ChatInputArea({
    super.key,
    required this.onSendMessage,
    required this.attachments,
    this.onVoiceRecorded,
    this.onTyping,
    this.onRecording,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showAttachments = false;

  /// Sélecteur d'emojis ouvert à la place du clavier.
  bool _showEmoji = false;

  /// Dernier état « champ rempli » : la zone n'est redessinée qu'au changement,
  /// pas à chaque touche.
  bool _lastHasText = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  _VoiceState _voiceState = _VoiceState.idle;
  _VoiceFormat? _voiceFormat;
  bool _isStarting = false;
  bool _isPressing = false;
  bool _isPaused = false;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedSince;
  double _dragOffset = 0.0;
  DateTime? _startTime;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  final List<double> _levelsDb = [];
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Le clavier et le panneau occupent la même place : l'un ferme l'autre.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && (_showAttachments || _showEmoji)) {
        setState(() {
          _showAttachments = false;
          _showEmoji = false;
        });
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    // Signal à chaque frappe : le contrôleur limite lui-même les envois (1 toutes les 3 s)
    // et prévient « a arrêté d'écrire » après 4 s sans frappe.
    widget.onTyping?.call(hasText);
    if (hasText == _lastHasText) return; // rien ne change à l'écran : pas de reconstruction
    _lastHasText = hasText;
    setState(() {}); // micro ↔ bouton d'envoi
  }

  /// Ouvre ou ferme le sélecteur d'emojis (il remplace le clavier, comme sur WhatsApp).
  void _toggleEmoji() {
    HapticFeedback.selectionClick();
    if (_showEmoji) {
      _focusNode.requestFocus();
      return;
    }
    _focusNode.unfocus();
    setState(() {
      _showEmoji = true;
      _showAttachments = false;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    if (_voiceState == _VoiceState.holding || _voiceState == _VoiceState.locked) {
      widget.onRecording?.call(false);
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  void _toggleAttachments() {
    HapticFeedback.selectionClick();
    if (!_showAttachments) _focusNode.unfocus();
    setState(() {
      _showAttachments = !_showAttachments;
      _showEmoji = false;
    });
  }

  void _pickAttachment(ChatAttachmentOption option) {
    setState(() => _showAttachments = false);
    option.onTap();
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
          .listen((amplitude) {
        if (_isPaused) return;
        _levelsDb.add(amplitude.current);
        if (_voiceState == _VoiceState.locked && mounted) setState(() {});
      });

      HapticFeedback.mediumImpact();
      setState(() {
        _showAttachments = false;
        _voiceState = _VoiceState.holding;
        _startTime = DateTime.now();
        _isPaused = false;
        _pausedTotal = Duration.zero;
        _pausedSince = null;
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
    if (!mounted || _isPaused) return;
    final elapsed = _elapsed;
    setState(() => _recordDuration = elapsed);

    if (timer.tick % _recordingSignalEverySeconds == 0) widget.onRecording?.call(true);

    if (elapsed >= _maxRecordingDuration) {
      _showHint('Durée maximale de 5 minutes atteinte');
      if (_voiceState == _VoiceState.locked) {
        _sendLockedRecording();
      } else {
        _sendHeldRecording();
      }
    }
  }

  /// Durée réellement enregistrée : les pauses ne comptent pas.
  Duration get _elapsed {
    final start = _startTime;
    if (start == null) return Duration.zero;
    final now = DateTime.now();
    final pausedNow = _pausedSince == null ? Duration.zero : now.difference(_pausedSince!);
    return now.difference(start) - _pausedTotal - pausedNow;
  }

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
    _isPaused = false;
    _pausedSince = null;
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

  Future<void> _togglePause() async {
    HapticFeedback.selectionClick();
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        setState(() {
          _pausedTotal += DateTime.now().difference(_pausedSince!);
          _pausedSince = null;
          _isPaused = false;
        });
        widget.onRecording?.call(true);
      } else {
        await _audioRecorder.pause();
        setState(() {
          _recordDuration = _elapsed;
          _pausedSince = DateTime.now();
          _isPaused = true;
        });
        widget.onRecording?.call(false);
      }
    } catch (e) {
      debugPrint('Pause du vocal impossible: $e');
      _showHint('Pause impossible sur cet appareil');
    }
  }

  Future<void> _sendLockedRecording() async {
    if (_voiceState != _VoiceState.locked) return;
    final duration = _elapsed;
    _resetRecordingUi();
    setState(() {
      _voiceState = _VoiceState.idle;
      _isPaused = false;
    });
    final path = await _audioRecorder.stop();
    if (path != null) _emitRecording(path, duration);
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

  String _formatDuration(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasText = _controller.text.isNotEmpty;
    final bool isIdle = _voiceState == _VoiceState.idle;
    final bool isHolding = _voiceState == _VoiceState.holding;
    final bool isCancelling = _dragOffset < _cancelDragDistance;

    final isDark = theme.brightness == Brightness.dark;
    final fieldColor = isDark ? OliChatDarkColors.receivedBubble : Colors.grey[100];

    final attachmentsOpen = _showAttachments && isIdle;
    final emojiOpen = _showEmoji && isIdle;
    final panelOpen = attachmentsOpen || emojiOpen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Un peu plus d'espace en bas : la barre ne colle pas au bord du téléphone.
          padding: EdgeInsets.fromLTRB(8, 8, 8, panelOpen ? 10 : 14),
          decoration: BoxDecoration(
            color: isDark ? OliChatDarkColors.bar : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            // Le panneau ouvert prend en charge le bas de l'écran.
            bottom: !panelOpen,
            child: _buildInputRow(theme, fieldColor, hasText, isIdle, isHolding, isCancelling),
          ),
        ),
        AnimatedSize(
          duration: _panelAnimation,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: attachmentsOpen
              ? _buildAttachmentPanel(isDark)
              : emojiOpen
                  ? _buildEmojiPanel(isDark)
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildInputRow(ThemeData theme, Color? fieldColor, bool hasText, bool isIdle, bool isHolding, bool isCancelling) {
    if (_voiceState == _VoiceState.locked) return _buildLockedRecorder(fieldColor);
    return Row(
          children: [
            if (isIdle)
              IconButton(
                tooltip: _showAttachments ? 'Clavier' : 'Joindre',
                // Panneau ouvert : l'icône clavier ramène la saisie, comme sur WhatsApp.
                icon: AnimatedSwitcher(
                  duration: _panelAnimation,
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: _showAttachments
                      ? Icon(Icons.keyboard_alt_outlined, key: const ValueKey('keyboard'), color: theme.iconTheme.color, size: 26)
                      : Icon(Icons.add_circle_outline, key: const ValueKey('add'), color: theme.primaryColor, size: 28),
                ),
                onPressed: widget.attachments.isEmpty
                    ? null
                    : _showAttachments
                        ? _focusNode.requestFocus
                        : _toggleAttachments,
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
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                          isDense: true,
                          // Emojis ↔ clavier
                          suffixIcon: IconButton(
                            tooltip: _showEmoji ? 'Clavier' : 'Emojis',
                            splashRadius: 20,
                            icon: Icon(
                              _showEmoji ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
                              color: theme.iconTheme.color?.withValues(alpha: 0.7),
                              size: 24,
                            ),
                            onPressed: _toggleEmoji,
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                        ),
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 50,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _buildHoldingContent(isCancelling),
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
    );
  }

  /// Panneau en verre dépoli aux coins arrondis, à la hauteur d'un clavier,
  /// avec des pastilles rondes et des icônes colorées, à la manière de WhatsApp.
  /// Packs d'emojis : récents, smileys, personnes, animaux et nature, nourriture,
  /// activités, voyages, objets, symboles, drapeaux — recherche et couleurs de peau.
  Widget _buildEmojiPanel(bool isDark) {
    final background = isDark ? OliChatDarkColors.bar : Colors.white;
    const oliBlue = Color(0xFF1E7DBA);
    return SafeArea(
      top: false,
      child: EmojiPicker(
        textEditingController: _controller,
        config: Config(
          height: 290,
          checkPlatformCompatibility: true,
          locale: const Locale('fr'),
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: background,
            columns: 8,
            emojiSizeMax: 28,
            noRecents: Text(
              'Aucun emoji récent',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: background,
            indicatorColor: oliBlue,
            iconColorSelected: oliBlue,
            iconColor: isDark ? Colors.white38 : Colors.black38,
            backspaceColor: oliBlue,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: background,
            buttonColor: background,
            buttonIconColor: isDark ? Colors.white70 : Colors.black54,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: background,
            buttonIconColor: isDark ? Colors.white70 : Colors.black54,
            hintText: 'Rechercher un emoji',
          ),
          skinToneConfig: const SkinToneConfig(dialogBackgroundColor: Colors.white, indicatorColor: oliBlue),
        ),
      ),
    );
  }

  Widget _buildAttachmentPanel(bool isDark) {
    final media = MediaQuery.of(context);
    final height = (media.size.height * 0.36).clamp(260.0, 340.0) + media.padding.bottom;
    final panelColor = isDark
        ? const Color(0xFF1E2329).withValues(alpha: 0.92)
        : const Color(0xFFE4E4EA).withValues(alpha: 0.9);
    final circleColor = isDark ? const Color(0xFF2E343C) : Colors.white;
    final labelColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_panelRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: height,
            width: double.infinity,
            color: panelColor,
            padding: EdgeInsets.fromLTRB(12, 34, 12, 12 + media.padding.bottom),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _attachmentColumns;
                return Wrap(
                  runSpacing: 26,
                  children: [
                    for (final option in widget.attachments)
                      SizedBox(
                        width: itemWidth,
                        child: Semantics(
                          button: true,
                          label: option.label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pickAttachment(option),
                            child: Column(
                              children: [
                                Container(
                                  width: _attachmentCircle,
                                  height: _attachmentCircle,
                                  decoration: BoxDecoration(
                                    color: circleColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    option.icon,
                                    // Une icône foncée resterait invisible sur une pastille sombre
                                    color: isDark && option.color.computeLuminance() < 0.1 ? Colors.white : option.color,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, color: labelColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
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

  /// Vocal verrouillé : durée et onde en direct, puis supprimer, pause et envoyer.
  Widget _buildLockedRecorder(Color? fieldColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final waveColor = isDark ? Colors.white : Colors.black87;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              Text(
                _formatDuration(_recordDuration),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: waveColor, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, 28),
                  painter: _LiveWaveformPainter(
                    levels: _levelsDb,
                    color: waveColor.withValues(alpha: _isPaused ? 0.45 : 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _recorderButton(
              tooltip: 'Supprimer le vocal',
              icon: Icons.delete_outline_rounded,
              iconColor: _recorderRed,
              background: _recorderRed.withValues(alpha: isDark ? 0.22 : 0.12),
              onPressed: _discardRecording,
            ),
            _recorderButton(
              tooltip: _isPaused ? "Reprendre l'enregistrement" : 'Mettre en pause',
              icon: _isPaused ? Icons.mic_rounded : Icons.pause_rounded,
              iconColor: _isPaused ? _recorderRed : waveColor,
              background: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
              onPressed: _togglePause,
            ),
            _recorderButton(
              tooltip: 'Envoyer le vocal',
              icon: Icons.send_rounded,
              iconColor: Colors.white,
              background: _recorderGreen,
              onPressed: _sendLockedRecording,
            ),
          ],
        ),
      ],
    );
  }

  Widget _recorderButton({
    required String tooltip,
    required IconData icon,
    required Color iconColor,
    required Color background,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: iconColor, size: 26),
      style: IconButton.styleFrom(
        backgroundColor: background,
        fixedSize: const Size.square(_recorderButtonSize),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// Onde de l'enregistrement en cours : les volumes les plus récents à droite,
/// des points pour le silence et la place encore libre.
class _LiveWaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  _LiveWaveformPainter({required List<double> levels, required this.color})
      : levels = List.of(levels);

  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / _liveBarSlot).floor();
    if (count <= 0) return;
    final recent = levels.length > count ? levels.sublist(levels.length - count) : levels;
    final offset = count - recent.length;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    for (var i = 0; i < count; i++) {
      final x = i * _liveBarSlot + _liveBarSlot / 2;
      final level = i < offset ? 0.0 : ((recent[i - offset] - _silenceDb) / -_silenceDb).clamp(0.0, 1.0);
      final height = math.max(2.4, size.height * level);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter oldDelegate) =>
      oldDelegate.levels.length != levels.length || oldDelegate.color != color;
}
