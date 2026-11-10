import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../../widgets/verification_badge.dart';
import '../../core/router/network/dio_provider.dart';
import 'call_quality_monitor.dart';
import 'socket_service.dart';

const _outgoingRingTimeout = Duration(seconds: 45);
const _incomingRingTimeout = Duration(seconds: 60);
const _connectionTimeout = Duration(seconds: 30);
const _reconnectionTimeout = Duration(seconds: 20);
const _qualityCheckInterval = Duration(seconds: 3);
const _moveMessage = 'Déplacez-vous vers un endroit mieux couvert.';

/// Interlocuteur de l'appel en cours : un seul appel à la fois sur cet appareil.
class ActiveCall {
  ActiveCall._();

  static String? peerId;
}

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

  late final Future<void> _renderersReady;
  Future<bool>? _webrtcReady;
  final List<RTCIceCandidate> _pendingCandidates = [];
  final CallQualityMonitor _qualityMonitor = CallQualityMonitor();
  Timer? _connectionTimer;
  Timer? _qualityTimer;
  bool _hasRemoteDescription = false;
  bool _isMediaConnected = false;
  bool _isReconnecting = false;
  bool _isConnectionWeak = false;
  bool _hasRestartedConnection = false;
  bool _isAccepting = false;
  bool _isClosing = false;
  bool _isCallInitiated = false;

  late String _displayName;
  BadgeType? _badgeType;

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
    _displayName = widget.otherName;
    ActiveCall.peerId = widget.otherId;

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

    _renderersReady = _initRenderers();
    _setupSocketListeners();
    _loadPeerIdentity();

    if (widget.isIncoming) {
      _timeoutTimer = Timer(_incomingRingTimeout, () {
        if (!_isCallActive) _endCallCleanup();
      });
    } else {
      _startOutgoingCall();
    }

    _playRingtone();
  }

  /// Le nom et la certification viennent du serveur, jamais de l'appelant.
  Future<void> _loadPeerIdentity() async {
    try {
      final response = await ref.read(dioProvider).get('/calls/peer/${widget.otherId}');
      if (!mounted || response.data is! Map) return;
      setState(() {
        _displayName = response.data['name']?.toString() ?? _displayName;
        _badgeType = VerificationBadge.fromUser(response.data);
      });
    } catch (e) {
      debugPrint("Identité de l'interlocuteur non chargée: $e");
    }
  }

  bool _isFromPeer(Map<String, dynamic> data) => data['fromId']?.toString() == widget.otherId;

  Future<bool> _prepareWebRTC() => _webrtcReady ??= _setupWebRTC();

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      if (widget.isIncoming) {
        // Sonnerie d'appel entrant
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      } else {
        // Tonalité d'attente (calling)
        await _audioPlayer.play(AssetSource('sounds/calling.mp3'));
      }
    } catch (e) {
      debugPrint("Erreur lecture sonnerie (vérifiez que les fichiers ringtone.mp3 et calling.mp3 existent dans assets/sounds/) : $e");
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<bool> _setupWebRTC() async {
    await _renderersReady;

    // Request permissions
    await [Permission.microphone, if (widget.isVideoCall) Permission.camera].request();

    // Create Peer Connection
    _peerConnection = await createPeerConnection(_iceServers);

    final peerConnection = _peerConnection!;

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (!mounted) return;
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      ref.read(socketServiceProvider).emit('webrtc_ice_candidate', {
        'toId': widget.otherId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    peerConnection.onIceConnectionState = _handleIceConnectionState;

    // Setup Local Stream
    final mediaConstraints = {
      'audio': kIsWeb
          ? {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}
          : {
              'optional': [
                {'googNoiseSuppression': 'true'},
                {'googEchoCancellation': 'true'},
                {'echoCancellation': 'true'},
                {'googAutoGainControl': 'true'},
                {'googHighpassFilter': 'true'},
              ],
            },
      'video': _isVideoEnabled
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (!mounted) {
        _localStream?.getTracks().forEach((track) => track.stop());
        return false;
      }
      _localRenderer.srcObject = _localStream;

      for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
        await _peerConnection?.addTrack(track, _localStream!);
      }
    } catch (e) {
      debugPrint("MediaStream Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'accéder au micro ou à la caméra.")),
        );
      }
      _abortCall();
      return false;
    }

    return true;
  }

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.onCallAccepted((data) async {
      if (!mounted || !_isFromPeer(data)) return;
      setState(() => _isCallActive = true);
      _timeoutTimer?.cancel();
      _audioPlayer.stop();
      _pulseController.stop();
      if (widget.isVideoCall) {
        setState(() => _isSpeakerOn = true);
        Helper.setSpeakerphoneOn(true);
      }
      _startConnectionWait();
      await _createOffer();
    });

    socket.onCallRejected((data) {
      if (!mounted || !_isFromPeer(data)) return;
      final message = switch (data['reason']) {
        'blocked' => 'Ce contact vous a bloqué. Votre appel ne peut pas aboutir.',
        'busy' => 'Ce correspondant est déjà en communication.',
        _ => 'Appel refusé',
      };
      _endCallWithMessage(message);
    });

    socket.onCallCancelled((data) {
      if (mounted && _isFromPeer(data)) _endCallCleanup();
    });

    socket.onCallEnded((data) {
      if (mounted && _isFromPeer(data)) _endCallCleanup();
    });

    // === WebRTC Signaling ===
    socket.onWebrtcOffer((data) async {
      if (!mounted || !_isCallActive || !_isFromPeer(data)) return;
      await _handleOffer(data['sdp']);
    });

    socket.onWebrtcAnswer((data) async {
      if (!mounted || _peerConnection == null || !_isFromPeer(data)) return;
      try {
        final answer = RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']);
        await _peerConnection?.setRemoteDescription(answer);
        await _applyPendingCandidates();
      } catch (e) {
        debugPrint("Set Remote Desc (Answer) error: $e");
      }
    });

    socket.onWebrtcIceCandidate((data) async {
      if (!mounted || !_isFromPeer(data)) return;
      final received = data['candidate'];
      final candidate = RTCIceCandidate(received['candidate'], received['sdpMid'], received['sdpMLineIndex']);

      // Trop tôt : le candidat sera appliqué après la description distante
      if (_peerConnection == null || !_hasRemoteDescription) {
        _pendingCandidates.add(candidate);
        return;
      }
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint("Add ICE candidate error: $e");
      }
    });
  }

  Future<void> _applyPendingCandidates() async {
    _hasRemoteDescription = true;
    final candidates = List<RTCIceCandidate>.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint("Add pending ICE candidate error: $e");
      }
    }
  }

  void _startOutgoingCall() {
    final socket = ref.read(socketServiceProvider);

    // L'appel ne sonne qu'une fois le micro prêt
    _prepareWebRTC().then((isReady) {
      if (!isReady || !mounted || _isClosing) return;
      _isCallInitiated = true;
      socket.emit('webrtc_call_initiate', {
        'toId': widget.otherId,
        'type': widget.isVideoCall ? 'video' : 'audio',
        'conversationId': widget.conversationId,
      });
    });

    _timeoutTimer = Timer(_outgoingRingTimeout, () {
      if (_isCallActive) return;
      socket.emit('webrtc_call_cancel', {'toId': widget.otherId, 'reason': 'timeout'});
      socket.emit('webrtc_call_missed', {
        'toId': widget.otherId,
        'type': widget.isVideoCall ? 'video' : 'audio',
        'conversationId': widget.conversationId,
      });
      _endCallCleanup();
    });
  }

  Future<void> _acceptCall() async {
    if (_isAccepting) return;
    _isAccepting = true;
    _timeoutTimer?.cancel();
    await _audioPlayer.stop();
    _pulseController.stop();
    _slideController.stop();

    // L'autre appareil n'envoie son offre qu'après l'acceptation : le micro doit être prêt avant
    if (!await _prepareWebRTC() || !mounted) return;

    setState(() => _isCallActive = true);
    if (widget.isVideoCall) {
      setState(() => _isSpeakerOn = true);
      Helper.setSpeakerphoneOn(true);
    }

    ref.read(socketServiceProvider).emit('webrtc_call_accept', {
      'callerId': widget.otherId,
    });
    _startConnectionWait();
  }

  Future<void> _createOffer({bool restartIce = false}) async {
    if (!await _prepareWebRTC() || _peerConnection == null) return;

    try {
      final offer = await _peerConnection!.createOffer(restartIce ? {'iceRestart': true} : {});
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
    if (!await _prepareWebRTC() || _peerConnection == null) return;
    try {
      final offer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection?.setRemoteDescription(offer);
      await _applyPendingCandidates();

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

  void _handleIceConnectionState(RTCIceConnectionState state) {
    if (!mounted || _isClosing) return;

    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _onMediaConnected();
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      _onConnectionLost();
    } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      _onConnectionLost();
      if (!widget.isIncoming && !_hasRestartedConnection) {
        _hasRestartedConnection = true;
        _createOffer(restartIce: true);
      }
    }
  }

  void _startConnectionWait() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer(_connectionTimeout, () => _endForLostConnection('Connexion impossible. $_moveMessage'));
  }

  void _onMediaConnected() {
    _connectionTimer?.cancel();
    _hasRestartedConnection = false;
    final isFirstConnection = !_isMediaConnected;
    setState(() {
      _isMediaConnected = true;
      _isReconnecting = false;
    });
    if (isFirstConnection) {
      _startCallTimer();
      _startQualityChecks();
    }
  }

  void _onConnectionLost() {
    if (!_isMediaConnected) return;
    setState(() => _isReconnecting = true);
    _connectionTimer?.cancel();
    _connectionTimer = Timer(_reconnectionTimeout, () => _endForLostConnection('La connexion a été perdue. $_moveMessage'));
  }

  void _endForLostConnection(String message) {
    ref.read(socketServiceProvider).emit('webrtc_call_ended', {'toId': widget.otherId});
    _endCallWithMessage(message);
  }

  void _startQualityChecks() {
    _qualityTimer = Timer.periodic(_qualityCheckInterval, (_) async {
      final peerConnection = _peerConnection;
      if (peerConnection == null || !mounted || _isReconnecting) return;
      try {
        final isWeak = _qualityMonitor.update(await peerConnection.getStats()) == CallQuality.poor;
        if (mounted && isWeak != _isConnectionWeak) setState(() => _isConnectionWeak = isWeak);
      } catch (e) {
        debugPrint('Mesure de la connexion impossible: $e');
      }
    });
  }

  void _abortCall() {
    final socket = ref.read(socketServiceProvider);
    if (widget.isIncoming) {
      socket.emit('webrtc_call_reject', {'callerId': widget.otherId});
    } else if (_isCallActive) {
      socket.emit('webrtc_call_ended', {'toId': widget.otherId});
    } else if (_isCallInitiated) {
      socket.emit('webrtc_call_cancel', {'toId': widget.otherId});
    }
    _endCallCleanup();
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
      if (_isCallInitiated) {
        socket.emit('webrtc_call_cancel', {'toId': widget.otherId});
        socket.emit('webrtc_call_missed', {
          'toId': widget.otherId,
          'type': widget.isVideoCall ? 'video' : 'audio',
          'conversationId': widget.conversationId,
        });
      }
    } else {
      socket.emit('webrtc_call_ended', {'toId': widget.otherId});
    }
    _endCallCleanup();
  }

  void _endCallWithMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    _endCallCleanup();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _endCallCleanup() {
    if (_isClosing) return;
    _isClosing = true;

    _timeoutTimer?.cancel();
    _connectionTimer?.cancel();
    _qualityTimer?.cancel();
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
    if (ActiveCall.peerId == widget.otherId) ActiveCall.peerId = null;
    _timeoutTimer?.cancel();
    _connectionTimer?.cancel();
    _qualityTimer?.cancel();
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
    // Haut-parleur : un seul appel, indépendant du nombre de pistes
    Helper.setSpeakerphoneOn(_isSpeakerOn);
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
                SizedBox(height: _isReconnecting || _isConnectionWeak ? 12 : 48),

                Text(
                  _isReconnecting
                      ? 'Reconnexion...'
                      : (_isMediaConnected
                          ? _formattedCallTime
                          : (_isCallActive
                              ? 'Connexion...'
                              : (widget.isIncoming ? 'Appel entrant...' : 'Appel en cours...'))),
                  style: TextStyle(
                    color: _isMediaConnected && !_isReconnecting ? Colors.greenAccent : Colors.white54,
                    fontSize: 15,
                    fontWeight: _isMediaConnected ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1.2,
                  ),
                ),

                if (_isReconnecting || _isConnectionWeak)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: _ConnectionWarning(
                      message: _isReconnecting
                          ? 'Connexion perdue. $_moveMessage'
                          : 'Connexion faible. $_moveMessage',
                    ),
                  ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_badgeType != null) ...[
                        const SizedBox(width: 8),
                        VerificationBadge(type: _badgeType!, size: 26),
                      ],
                    ],
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

                // La photo se réduit sur les petits écrans pour laisser la place aux boutons
                if (!_isVideoEnabled)
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
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
                      ),
                    ),
                  )
                else
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

class _ConnectionWarning extends StatelessWidget {
  final String message;

  const _ConnectionWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6B45309),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.signal_cellular_connected_no_internet_4_bar, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
