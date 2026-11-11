import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' hide AndroidAudioMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import '../../../../widgets/verification_badge.dart';
import '../../core/router/network/dio_provider.dart';
import '../../core/services/native_call_service.dart';
import '../../core/user/user_provider.dart';
import 'call_quality_monitor.dart';
import 'socket_service.dart';

const _outgoingRingTimeout = Duration(seconds: 45);
const _incomingRingTimeout = Duration(seconds: 60);
const _connectionTimeout = Duration(seconds: 30);
const _reconnectionTimeout = Duration(seconds: 20);
const _qualityCheckInterval = Duration(seconds: 3);
const _moveMessage = 'Déplacez-vous vers un endroit mieux couvert.';
const _iceServersTimeout = Duration(seconds: 4);

/// Relevé temporaire, à retirer une fois le son des appels validé sur de vrais téléphones.
const _showCallDiagnostics = true;
const _callDiagnosticsVersion = 'diag-3';
const _diagnosticsInterval = Duration(seconds: 2);

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

  /// L'appel a déjà été accepté depuis l'écran natif du téléphone.
  final bool autoAccept;

  const CallScreen({
    super.key,
    required this.otherId,
    this.conversationId,
    required this.otherName,
    this.otherAvatarUrl,
    this.isVideoCall = false,
    this.isIncoming = false,
    this.autoAccept = false,
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

  /// Ma caméra envoie une image (indépendant de ce que l'autre envoie).
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  bool _isOpeningCamera = false;

  /// Caméra ouverte en cours d'appel, quand elle n'a pas pu l'être au départ.
  MediaStream? _cameraStream;

  /// L'autre appareil envoie une piste vidéo, et sa caméra n'est pas coupée.
  bool _hasRemoteVideo = false;
  bool _isRemoteCameraOn = true;
  bool get _showRemoteVideo => _hasRemoteVideo && _isRemoteCameraOn;

  List<MediaStreamTrack> get _localVideoTracks => [
        ...?_localStream?.getVideoTracks(),
        ...?_cameraStream?.getVideoTracks(),
      ];

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

  String _iceStateLabel = 'New';
  /// Nombre de relais TURN reçus du serveur : 0 explique un appel bloqué sur « Connexion… ».
  int _relayServerCount = 0;
  final Set<String> _localCandidateTypes = {};
  final Set<String> _remoteCandidateTypes = {};
  int _audioBytesSent = 0;
  int _audioBytesReceived = 0;
  int _videoBytesSent = 0;
  int _videoBytesReceived = 0;
  bool _hasMicrophoneTrack = false;
  Timer? _diagnosticsTimer;

  /// Navigateur : la sonnerie attend un premier toucher de l'utilisateur.
  bool _needsSoundUnlock = false;

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

    // Comme un vrai appel : l'écran ne s'éteint pas pendant la sonnerie et la conversation
    WakelockPlus.enable().catchError((Object e) => debugPrint('Écran allumé impossible: $e'));

    _renderersReady = _initRenderers();
    _setupSocketListeners();
    _loadPeerIdentity();

    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _acceptCall());
    } else if (widget.isIncoming) {
      _timeoutTimer = Timer(_incomingRingTimeout, () {
        if (!_isCallActive) _endCallCleanup();
      });
    } else {
      _startOutgoingCall();
    }

    if (!widget.autoAccept) _playRingtone();
  }

  /// En cas d'échec, l'appel tente quand même une connexion directe.
  Future<Map<String, dynamic>> _loadIceServers() async {
    try {
      final response = await ref.read(dioProvider).get('/calls/ice-servers').timeout(_iceServersTimeout);
      final servers = response.data is Map ? response.data['iceServers'] : null;
      if (servers is List && servers.isNotEmpty) {
        _relayServerCount = servers.where((s) => s is Map && '${s['urls']}'.contains('turn')).length;
        return {'iceServers': servers};
      }
    } catch (e) {
      debugPrint('Serveurs de connexion non chargés: $e');
    }
    return _iceServers;
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

  static final _ringbackAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunicationSignalling,
      audioFocus: AndroidAudioFocus.none,
      audioMode: AndroidAudioMode.inCommunication,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const [AVAudioSessionOptions.allowBluetooth],
    ),
  );

  Future<void> _prepareCallAudio() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Helper.setAndroidAudioConfiguration(AndroidAudioConfiguration.communication);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Helper.setAppleAudioIOMode(AppleAudioIOMode.localAndRemote);
      }
    } catch (e) {
      debugPrint('Configuration audio impossible: $e');
    }
  }

  /// La sonnerie vient de s'arrêter : l'audio repasse à la conversation.
  Future<void> _restoreCallAudioRoute() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Helper.setAppleAudioIOMode(AppleAudioIOMode.localAndRemote, preferSpeakerOutput: _isSpeakerOn);
      }
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (e) {
      debugPrint('Sortie audio non appliquée: $e');
    }
  }

  /// Après un démarrage par l'écran natif, la connexion en direct n'est pas encore ouverte.
  Future<bool> _ensureSocketConnected() async {
    final socket = ref.read(socketServiceProvider);
    for (var attempt = 0; attempt < 50 && mounted; attempt++) {
      if (socket.isConnected) return true;
      final userId = ref.read(userProvider).value?.id.toString();
      if (userId != null) await socket.connect(userId);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return socket.isConnected;
  }

  bool _isFromPeer(Map<String, dynamic> data) => data['fromId']?.toString() == widget.otherId;

  Future<bool> _prepareWebRTC() => _webrtcReady ??= _setupWebRTC();

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Sans ce réglage, la tonalité d'attente coupe le mode audio de l'appel sur téléphone
      if (!kIsWeb && !widget.isIncoming) await _audioPlayer.setAudioContext(_ringbackAudioContext);
      if (widget.isIncoming) {
        // Sonnerie d'appel entrant
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      } else {
        // Tonalité d'attente (calling)
        await _audioPlayer.play(AssetSource('sounds/calling.mp3'));
      }
      if (_needsSoundUnlock && mounted) setState(() => _needsSoundUnlock = false);
    } catch (e) {
      debugPrint('Sonnerie non jouée : $e');
      // Le navigateur bloque le son tant que la page n'a pas été touchée
      if (kIsWeb && mounted && !_isCallActive) setState(() => _needsSoundUnlock = true);
    }
  }

  /// Premier toucher sur le navigateur : la sonnerie peut enfin jouer.
  void _unlockSound() {
    if (!_needsSoundUnlock || _isCallActive || _isClosing) return;
    _playRingtone();
  }

  /// Sur téléphone, le micro doit être autorisé par le système avant tout appel.
  /// Le navigateur, lui, pose la question au moment d'ouvrir le micro.
  Future<bool> _ensureMicrophonePermission() async {
    if (kIsWeb) return true;
    final statuses = await [Permission.microphone, if (_isVideoEnabled) Permission.camera].request();
    if (_isVideoEnabled && statuses[Permission.camera]?.isGranted != true) {
      // Sans caméra, l'appel continue en audio
      setState(() => _isVideoEnabled = false);
    }
    final microphone = statuses[Permission.microphone];
    if (microphone?.isGranted == true || microphone?.isLimited == true) return true;
    if (mounted && microphone?.isPermanentlyDenied == true) await _showMicrophoneSettingsDialog();
    return false;
  }

  Future<void> _showMicrophoneSettingsDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Micro bloqué'),
        content: const Text("Oli a besoin du micro pour l'appel. Autorisez-le dans les réglages du téléphone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ouvrir les réglages'),
          ),
        ],
      ),
    );
  }

  /// Message compréhensible selon la raison pour laquelle le micro n'a pas pu s'ouvrir.
  String _microphoneErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('NotAllowed') || text.contains('Permission') || text.contains('denied')) {
      return kIsWeb
          ? "Micro refusé. Autorisez-le avec l'icône à gauche de l'adresse du site, puis rappelez."
          : 'Micro refusé. Autorisez-le dans les réglages du téléphone.';
    }
    if (text.contains('NotFound') || text.contains('DevicesNotFound')) return 'Aucun micro détecté sur cet appareil.';
    if (text.contains('NotReadable') || text.contains('TrackStart')) {
      return 'Le micro est déjà utilisé par une autre application.';
    }
    if (text.contains('Secure') || text.contains('secure')) return "L'appel nécessite une connexion sécurisée (https).";
    return "Impossible d'ouvrir le micro.";
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<bool> _setupWebRTC() async {
    try {
      await _renderersReady;
      await _prepareCallAudio();

      if (!await _ensureMicrophonePermission()) {
        _failSetup('Micro refusé. Autorisez-le dans les réglages du téléphone.');
        return false;
      }

      // Le micro s'ouvre d'abord : c'est lui qui déclenche la demande du navigateur
      final stream = await _openLocalStream();
      if (!mounted || _isClosing) {
        stream.getTracks().forEach((track) => track.stop());
        return false;
      }
      _localStream = stream;
      _localRenderer.srcObject = stream;
      _hasMicrophoneTrack = stream.getAudioTracks().isNotEmpty;
      if (!_hasMicrophoneTrack) {
        _failSetup('Aucun micro détecté sur cet appareil.');
        return false;
      }

      _peerConnection = await createPeerConnection(await _loadIceServers());
      final peerConnection = _peerConnection!;

      peerConnection.onTrack = (RTCTrackEvent event) {
        if (!mounted) return;
        if (event.streams.isEmpty) return;
        setState(() {
          _remoteStream = event.streams[0];
          // Réaffecté à chaque piste : la vidéo peut arriver après le son
          _remoteRenderer.srcObject = _remoteStream;
          if (event.track.kind == 'video') _hasRemoteVideo = true;
        });
      };

      peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
        _recordCandidateType(_localCandidateTypes, candidate.candidate);
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

      for (final track in stream.getTracks()) {
        await peerConnection.addTrack(track, stream);
      }
      // Sans caméra, l'appelant réserve quand même une voie vidéo pour recevoir celle de l'autre
      if (widget.isVideoCall && !widget.isIncoming && stream.getVideoTracks().isEmpty) {
        await peerConnection.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      }
      if (mounted) setState(() {});
      _startDiagnostics();
      return true;
    } catch (e) {
      debugPrint('Préparation de l\'appel impossible: $e');
      _failSetup(_microphoneErrorMessage(e));
      return false;
    }
  }

  Map<String, dynamic> get _audioConstraints => kIsWeb
      ? {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}
      : {
          'optional': [
            {'googNoiseSuppression': 'true'},
            {'googEchoCancellation': 'true'},
            {'echoCancellation': 'true'},
            {'googAutoGainControl': 'true'},
            {'googHighpassFilter': 'true'},
          ],
        };

  static const Map<String, dynamic> _videoConstraints = {
    'facingMode': 'user',
    'width': {'ideal': 640},
    'height': {'ideal': 480},
  };

  /// Micro (et caméra pour la vidéo). Si la caméra échoue, l'appel continue sans elle.
  Future<MediaStream> _openLocalStream() async {
    if (_isVideoEnabled) {
      try {
        return await navigator.mediaDevices.getUserMedia({
          'audio': _audioConstraints,
          'video': _videoConstraints,
        });
      } catch (e) {
        debugPrint('Caméra indisponible, appel en audio: $e');
        if (mounted) setState(() => _isVideoEnabled = false);
      }
    }
    return navigator.mediaDevices.getUserMedia({'audio': _audioConstraints, 'video': false});
  }

  /// L'appel ne peut pas démarrer : on prévient l'autre appareil et on explique pourquoi.
  void _failSetup(String message) {
    if (!mounted || _isClosing) return;
    final messenger = ScaffoldMessenger.of(context);
    _abortCall();
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
  }

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.onCallAccepted((data) async {
      if (!mounted || !_isFromPeer(data)) return;
      setState(() => _isCallActive = true);
      _timeoutTimer?.cancel();
      await _audioPlayer.stop();
      _pulseController.stop();
      if (widget.isVideoCall) setState(() => _isSpeakerOn = true);
      await _restoreCallAudioRoute();
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

    socket.onWebrtcVideoState((data) {
      if (!mounted || !_isFromPeer(data)) return;
      setState(() => _isRemoteCameraOn = data['enabled'] == true);
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
      _recordCandidateType(_remoteCandidateTypes, received['candidate']?.toString());
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

    if (!await _ensureSocketConnected() || !mounted) {
      if (mounted) _endCallWithMessage('Connexion impossible. $_moveMessage');
      return;
    }
    if (widget.autoAccept) NativeCallService.endForCaller(widget.otherId);

    setState(() => _isCallActive = true);
    if (widget.isVideoCall) setState(() => _isSpeakerOn = true);
    await _restoreCallAudioRoute();

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

  void _recordCandidateType(Set<String> types, String? candidate) {
    final type = RegExp(r' typ (\w+)').firstMatch(candidate ?? '')?.group(1);
    if (type != null && mounted) setState(() => types.add(type));
  }

  void _startDiagnostics() {
    if (!_showCallDiagnostics) return;
    _diagnosticsTimer = Timer.periodic(_diagnosticsInterval, (_) async {
      final peerConnection = _peerConnection;
      if (peerConnection == null || !mounted) return;
      try {
        var sent = _audioBytesSent;
        var received = _audioBytesReceived;
        var videoSent = _videoBytesSent;
        var videoReceived = _videoBytesReceived;
        for (final report in await peerConnection.getStats()) {
          final kind = report.values['kind'] ?? report.values['mediaType'];
          final bytesSent = int.tryParse('${report.values['bytesSent']}');
          final bytesReceived = int.tryParse('${report.values['bytesReceived']}');
          if (kind == 'audio') {
            if (report.type == 'outbound-rtp') sent = bytesSent ?? sent;
            if (report.type == 'inbound-rtp') received = bytesReceived ?? received;
          } else if (kind == 'video') {
            if (report.type == 'outbound-rtp') videoSent = bytesSent ?? videoSent;
            if (report.type == 'inbound-rtp') videoReceived = bytesReceived ?? videoReceived;
          }
        }
        if (mounted) {
          setState(() {
            _audioBytesSent = sent;
            _audioBytesReceived = received;
            _videoBytesSent = videoSent;
            _videoBytesReceived = videoReceived;
          });
        }
      } catch (e) {
        debugPrint('Relevé de connexion impossible: $e');
      }
    });
  }

  String get _diagnosticsText {
    String kilobytes(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} Ko';
    String types(Set<String> values) => values.isEmpty ? 'aucun' : values.join('+');
    final video = widget.isVideoCall
        ? '\nvidéo : caméra ${_isVideoEnabled ? 'oui' : 'non'} · envoyé ${kilobytes(_videoBytesSent)} · '
            'reçu ${kilobytes(_videoBytesReceived)} · autre ${_hasRemoteVideo ? (_isRemoteCameraOn ? 'oui' : 'coupée') : 'aucune'}'
        : '';
    return '$_callDiagnosticsVersion · ${widget.isIncoming ? 'reçoit' : 'appelle'} · ICE $_iceStateLabel\n'
        'local ${types(_localCandidateTypes)} · distant ${types(_remoteCandidateTypes)} · '
        'micro ${_hasMicrophoneTrack ? 'oui' : 'non'} · relais $_relayServerCount\n'
        'son : envoyé ${kilobytes(_audioBytesSent)} · reçu ${kilobytes(_audioBytesReceived)}$video';
  }

  void _handleIceConnectionState(RTCIceConnectionState state) {
    if (!mounted || _isClosing) return;
    setState(() => _iceStateLabel = state.name.replaceFirst('RTCIceConnectionState', ''));

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
      // Une caméra coupée pendant la sonnerie doit être connue de l'autre dès la connexion
      if (widget.isVideoCall) _sendVideoState();
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
    WakelockPlus.disable().catchError((Object _) {});

    _timeoutTimer?.cancel();
    _connectionTimer?.cancel();
    _qualityTimer?.cancel();
    _diagnosticsTimer?.cancel();
    _callTimer?.cancel();
    _audioPlayer.stop();

    _localStream?.getTracks().forEach((track) => track.stop());
    _cameraStream?.getTracks().forEach((track) => track.stop());
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
    WakelockPlus.disable().catchError((Object _) {});
    _timeoutTimer?.cancel();
    _connectionTimer?.cancel();
    _qualityTimer?.cancel();
    _diagnosticsTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    
    _localStream?.getTracks().forEach((t) => t.stop());
    _cameraStream?.getTracks().forEach((t) => t.stop());
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

  Future<void> _toggleVideo() async {
    final tracks = _localVideoTracks;
    if (tracks.isEmpty) return _startCamera();
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    for (final track in tracks) {
      track.enabled = _isVideoEnabled;
    }
    _sendVideoState();
  }

  /// L'autre affiche « Caméra désactivée » au lieu d'une image noire.
  void _sendVideoState() {
    ref.read(socketServiceProvider).emit('webrtc_video_state', {
      'toId': widget.otherId,
      'enabled': _isVideoEnabled,
    });
  }

  /// L'appel a démarré sans caméra : on l'ouvre maintenant et on renégocie la connexion.
  Future<void> _startCamera() async {
    final localStream = _localStream;
    final peerConnection = _peerConnection;
    if (_isOpeningCamera || localStream == null || peerConnection == null) return;
    _isOpeningCamera = true;
    try {
      if (!kIsWeb && !(await Permission.camera.request()).isGranted) {
        _showMessage('Caméra refusée. Autorisez-la dans les réglages du téléphone.');
        return;
      }
      final cameraStream = await navigator.mediaDevices.getUserMedia({'audio': false, 'video': _videoConstraints});
      if (!mounted || _isClosing) {
        cameraStream.getTracks().forEach((track) => track.stop());
        return;
      }
      _cameraStream = cameraStream;
      // Même flux que le micro : l'autre reçoit le son et l'image ensemble
      await peerConnection.addTrack(cameraStream.getVideoTracks().first, localStream);
      _localRenderer.srcObject = cameraStream;
      setState(() {
        _isVideoEnabled = true;
        _isFrontCamera = true;
      });
      _sendVideoState();
      await _createOffer();
    } catch (e) {
      debugPrint('Caméra non ouverte: $e');
      _showMessage("Impossible d'ouvrir la caméra.");
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _switchCamera() async {
    final tracks = _localVideoTracks;
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
    } catch (e) {
      debugPrint('Changement de caméra impossible: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  
  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    try {
      // Haut-parleur : un seul appel, indépendant du nombre de pistes
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (e) {
      debugPrint('Haut-parleur non appliqué: $e');
    }
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
              !_showRemoteVideo)
            Image.network(
              widget.otherAvatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildGradientBg(),
            )
          else
            _buildGradientBg(),

          if (!_showRemoteVideo)
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

          // Sans image distante, le lecteur reste présent, invisible, pour que le son soit joué
          if (!_showRemoteVideo)
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: IgnorePointer(child: Opacity(opacity: 0.01, child: RTCVideoView(_remoteRenderer))),
            ),

          // ── 2. Flux Vidéo ── l'image de l'autre ne dépend pas de ma caméra
          if (_showRemoteVideo)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),

          if (widget.isVideoCall && _hasRemoteVideo && !_isRemoteCameraOn)
            const Align(
              alignment: Alignment(0, 0.25),
              child: _VideoOffLabel(),
            ),

          if (_isVideoEnabled)
            Positioned(
              right: 20,
              bottom: 160,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // Miroir seulement pour la caméra avant, comme un miroir de salle de bain
                child: RTCVideoView(
                  _localRenderer,
                  mirror: _isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          if (_needsSoundUnlock)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _unlockSound,
                child: Align(
                  alignment: const Alignment(0, -0.35),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Flexible(child: Text('Touchez pour activer la sonnerie', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_showCallDiagnostics)
            Positioned(
              left: 8,
              right: 8,
              bottom: MediaQuery.of(context).padding.bottom + 2,
              child: IgnorePointer(
                child: Text(
                  _diagnosticsText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
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
              // Le navigateur choisit lui-même la sortie du son
              if (!kIsWeb)
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
              // Le navigateur ne sait pas remplacer la caméra envoyée
              if (widget.isVideoCall && !kIsWeb && _isVideoEnabled)
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  label: 'Retourner',
                  isActive: false,
                  onTap: _switchCamera,
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

/// L'autre a coupé sa caméra : on le dit au lieu d'afficher une image noire.
class _VideoOffLabel extends StatelessWidget {
  const _VideoOffLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Caméra désactivée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
