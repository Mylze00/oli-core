import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'socket_service.dart';

// === Stubs WebRTC ===
class RTCVideoRenderer {
  RTCVideoRenderer();
  Future<void> initialize() async {}
  void dispose() {}
}

class RTCVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final dynamic objectFit;
  const RTCVideoView(this.renderer, {super.key, this.mirror = false, this.objectFit});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class RTCVideoViewObjectFit {
  static const dynamic RTCVideoViewObjectFitCover = null;
}
// === End stubs ===

class CallScreen extends ConsumerStatefulWidget {
  final String otherId;
  final String? conversationId;
  final String otherName;
  final String? otherAvatarUrl;
  final bool isVideoCall;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.otherId,
    this.conversationId,
    required this.otherName,
    this.otherAvatarUrl,
    this.isVideoCall = false,
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCallActive = false;
  Timer? _timeoutTimer;

  // Chronomètre
  Timer? _callTimer;
  int _callSeconds = 0;

  // Animation de pulsation (sonnerie)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animation du bouton décrocher (slide)
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideoCall;

    // Animation pulsation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation slide
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initRenderers();
    _setupAudioAndSignaling();
  }

  void _setupAudioAndSignaling() {
    final socket = ref.read(socketServiceProvider);

    if (!widget.isIncoming) {
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!_isCallActive) {
          socket.emit('webrtc_call_cancel', {'toId': widget.otherId});
          socket.emit('webrtc_call_missed', {
            'toId': widget.otherId,
            'type': widget.isVideoCall ? 'video' : 'audio',
            'conversationId': widget.conversationId,
          });
          if (mounted) Navigator.pop(context);
        }
      });

      socket.onCallAccepted((data) {
        if (mounted) {
          setState(() {
            _isCallActive = true;
            _timeoutTimer?.cancel();
          });
          _audioPlayer.stop();
          _pulseController.stop();
          _startCallTimer();
        }
      });

      socket.onCallRejected((data) {
        if (mounted) {
          _timeoutTimer?.cancel();
          _audioPlayer.stop();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appel refusé')),
          );
        }
      });
    } else {
      socket.onCallCancelled((data) {
        if (mounted) {
          _audioPlayer.stop();
          Navigator.pop(context);
        }
      });
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  String get _formattedCallTime {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initRenderers() async {
    if (_isVideoEnabled) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    if (_isVideoEnabled) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  void _acceptCall() {
    setState(() => _isCallActive = true);
    _audioPlayer.stop();
    _pulseController.stop();
    _slideController.stop();
    ref.read(socketServiceProvider).emit('webrtc_call_accept', {
      'callerId': widget.otherId,
    });
    _startCallTimer();
  }

  void _rejectCall() {
    _audioPlayer.stop();
    ref.read(socketServiceProvider).emit('webrtc_call_reject', {
      'callerId': widget.otherId,
    });
    Navigator.pop(context);
  }

  void _endCall() {
    _timeoutTimer?.cancel();
    _callTimer?.cancel();
    _audioPlayer.stop();
    final socket = ref.read(socketServiceProvider);
    if (!_isCallActive && !widget.isIncoming) {
      socket.emit('webrtc_call_cancel', {'toId': widget.otherId});
      socket.emit('webrtc_call_missed', {
        'toId': widget.otherId,
        'type': widget.isVideoCall ? 'video' : 'audio',
        'conversationId': widget.conversationId,
      });
    } else {
      socket.emit('webrtc_call_ended', {'toId': widget.otherId});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Fond flouté avec avatar ──
          if (widget.otherAvatarUrl != null &&
              widget.otherAvatarUrl!.isNotEmpty &&
              !_isVideoEnabled)
            Image.network(
              widget.otherAvatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildGradientBg(),
            )
          else
            _buildGradientBg(),

          // Flou + overlay dégradé
          if (!_isVideoEnabled)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC0A1628),
                      Color(0xDD0D2137),
                      Color(0xFF000000),
                    ],
                  ),
                ),
              ),
            ),

          // ── 2. Flux Vidéo ──
          if (_isVideoEnabled)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),

          if (_isVideoEnabled)
            Positioned(
              right: 20,
              bottom: 160,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),

          // ── 3. Contenu principal ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Statut
                Text(
                  _isCallActive
                      ? _formattedCallTime
                      : (widget.isIncoming ? 'Appel entrant...' : 'Appel en cours...'),
                  style: TextStyle(
                    color: _isCallActive ? Colors.greenAccent : Colors.white54,
                    fontSize: 15,
                    fontWeight: _isCallActive ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                // Nom
                Text(
                  widget.otherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Type d'appel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isVideoCall ? Icons.videocam : Icons.phone,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isVideoCall ? 'Appel vidéo' : 'Appel audio',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Avatar avec animation de pulsation
                if (!_isVideoEnabled)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _isCallActive ? 1.0 : _pulseAnimation.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Cercles pulsants (sonnerie uniquement)
                          if (!_isCallActive) ...[
                            Transform.scale(
                              scale: scale * 1.35,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.04),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: scale * 1.18,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.07),
                                ),
                              ),
                            ),
                          ],
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isCallActive
                                    ? Colors.greenAccent.withOpacity(0.6)
                                    : Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _isCallActive
                                      ? Colors.greenAccent.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: AutoRefreshAvatar(
                              avatarUrl: widget.otherAvatarUrl,
                              size: 150,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                const Spacer(),

                // ── 4. Boutons de contrôle ──
                if (widget.isIncoming && !_isCallActive)
                  _buildIncomingButtons()
                else
                  _buildActiveCallButtons(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF000000)],
        ),
      ),
    );
  }

  // Boutons appel entrant : Refuser / Décrocher
  Widget _buildIncomingButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Refuser
          _buildCallActionButton(
            icon: Icons.call_end,
            color: const Color(0xFFFF3B30),
            label: 'Refuser',
            onTap: _rejectCall,
          ),
          // Décrocher
          _buildCallActionButton(
            icon: Icons.call,
            color: const Color(0xFF34C759),
            label: 'Décrocher',
            onTap: _acceptCall,
            pulse: true,
          ),
        ],
      ),
    );
  }

  // Boutons appel en cours / sortant
  Widget _buildActiveCallButtons() {
    return Column(
      children: [
        // Ligne de contrôles secondaires
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Muet' : 'Micro',
                isActive: _isMuted,
                onTap: () => setState(() => _isMuted = !_isMuted),
              ),
              _buildControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Haut-parl.',
                isActive: _isSpeakerOn,
                onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
              ),
              if (widget.isVideoCall)
                _buildControlButton(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'Caméra',
                  isActive: !_isVideoEnabled,
                  onTap: () => setState(() => _isVideoEnabled = !_isVideoEnabled),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Bouton raccrocher (centré et grand)
        _buildCallActionButton(
          icon: Icons.call_end,
          color: const Color(0xFFFF3B30),
          label: 'Raccrocher',
          onTap: _endCall,
        ),
      ],
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool pulse = false,
  }) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );

    if (pulse) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: btn,
      );
    }
    return btn;
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF0D47A1) : Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
