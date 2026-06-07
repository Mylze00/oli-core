import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'socket_service.dart';

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
  
  // === WebRTC ===
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Servers STUN
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCallActive = false;
  Timer? _timeoutTimer;

  // Chronomètre
  Timer? _callTimer;
  int _callSeconds = 0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideoCall;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initRenderers();
    _setupSocketListeners();
    
    if (!widget.isIncoming) {
      _startOutgoingCall();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _setupWebRTC() async {
    // Request permissions
    await [Permission.microphone, if (widget.isVideoCall) Permission.camera].request();

    // Create Peer Connection
    _peerConnection = await createPeerConnection(_iceServers);

    // Setup Local Stream
    final mediaConstraints = {
      'audio': true,
      'video': _isVideoEnabled
          ? {'facingMode': 'user', 'ideal': '720p'}
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    } catch (e) {
      debugPrint("MediaStream Error: $e");
    }

    // Handle Remote Stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    // Handle ICE Candidates
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      ref.read(socketServiceProvider).emit('webrtc_ice_candidate', {
        'toId': widget.otherId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };
  }

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.onCallAccepted((data) async {
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
        _endCallCleanup();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appel refusé')),
        );
      }
    });

    socket.onCallCancelled((data) {
      if (mounted) _endCallCleanup();
    });

    socket.onCallEnded((data) {
      if (mounted) _endCallCleanup();
    });

    // === WebRTC Signaling ===
    socket.onWebrtcOffer((data) async {
      if (!_isCallActive) return; // Prevent offer if call not accepted yet
      await _handleOffer(data['sdp']);
    });

    socket.onWebrtcAnswer((data) async {
      if (_peerConnection == null) return;
      try {
        final answer = RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']);
        await _peerConnection?.setRemoteDescription(answer);
      } catch (e) {
        debugPrint("Set Remote Desc (Answer) error: $e");
      }
    });

    socket.onWebrtcIceCandidate((data) async {
      if (_peerConnection == null) return;
      try {
        final cand = data['candidate'];
        await _peerConnection?.addCandidate(RTCIceCandidate(
          cand['candidate'],
          cand['sdpMid'],
          cand['sdpMLineIndex'],
        ));
      } catch (e) {
        debugPrint("Add ICE candidate error: $e");
      }
    });
  }

  void _startOutgoingCall() {
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isCallActive) {
        ref.read(socketServiceProvider).emit('webrtc_call_cancel', {'toId': widget.otherId});
        _endCallCleanup();
      }
    });
    // L'appelant (User A) a déjà émis webrtc_call_initiate avant d'ouvrir cet écran
  }

  Future<void> _acceptCall() async {
    setState(() => _isCallActive = true);
    _audioPlayer.stop();
    _pulseController.stop();
    _slideController.stop();
    
    // Notify peer
    ref.read(socketServiceProvider).emit('webrtc_call_accept', {
      'callerId': widget.otherId,
    });
    
    _startCallTimer();
    await _setupWebRTC();
  }

  // Caller creates offer AFTER getting the accept event
  // Wait! Let's make Caller A create the offer as soon as Call is Accepted.
  Future<void> _createOffer() async {
    await _setupWebRTC();
    if (_peerConnection == null) return;

    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      ref.read(socketServiceProvider).emit('webrtc_offer', {
        'toId': widget.otherId,
        'sdp': {'sdp': offer.sdp, 'type': offer.type}
      });
    } catch (e) {
      debugPrint("Create offer error: $e");
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> sdpMap) async {
    if (_peerConnection == null) return;
    try {
      final offer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection?.setRemoteDescription(offer);
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      ref.read(socketServiceProvider).emit('webrtc_answer', {
        'toId': widget.otherId,
        'sdp': {'sdp': answer.sdp, 'type': answer.type}
      });
    } catch (e) {
      debugPrint("Handle offer error: $e");
    }
  }

  void _rejectCall() {
    ref.read(socketServiceProvider).emit('webrtc_call_reject', {
      'callerId': widget.otherId,
    });
    _endCallCleanup();
  }

  void _endCall() {
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
    _endCallCleanup();
  }

  void _endCallCleanup() {
    _timeoutTimer?.cancel();
    _callTimer?.cancel();
    _audioPlayer.stop();
    
    _localStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _peerConnection?.close();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _startCallTimer() {
    // If I'm the caller, create the offer now
    if (!widget.isIncoming) {
      _createOffer();
    }
    
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  String get _formattedCallTime {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    
    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _peerConnection?.close();
    
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }
  
  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    // Dans flutter_webrtc mobile
    _localStream?.getAudioTracks().forEach((track) {
       Helper.setSpeakerphoneOn(_isSpeakerOn);
    });
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

                if (!_isVideoEnabled)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final scale = _isCallActive ? 1.0 : _pulseAnimation.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
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

  Widget _buildIncomingButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCallActionButton(
            icon: Icons.call_end,
            color: const Color(0xFFFF3B30),
            label: 'Refuser',
            onTap: _rejectCall,
          ),
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

  Widget _buildActiveCallButtons() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Muet' : 'Micro',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              _buildControlButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Haut-parl.',
                isActive: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
              if (widget.isVideoCall)
                _buildControlButton(
                  icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  label: 'Caméra',
                  isActive: !_isVideoEnabled,
                  onTap: _toggleVideo,
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
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
