import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
// flutter_webrtc removed — package no longer in pubspec
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/auto_refresh_avatar.dart';
import 'socket_service.dart';

// === Stub classes replacing flutter_webrtc (package removed from pubspec) ===
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

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCallActive = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideoCall;
    _initRenderers();
    _setupAudioAndSignaling();
  }

  void _setupAudioAndSignaling() {
    // Jouer la sonnerie en boucle
    // Note: Pour un vrai projet, télécharger un asset ou utiliser un ringtone natif. 
    // Ici on utilise flutter_ringtone_player ou audioplayers avec un asset par défaut (s'il y en a)
    // Comme il n'y a pas d'asset audio, on va jouer un bip silencieux ou s'en passer si on est sur le web sans interaction.
    // Pour simuler:
    // _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // _audioPlayer.play(AssetSource('audio/ringtone.mp3'));

    final socket = ref.read(socketServiceProvider);

    if (!widget.isIncoming) {
      // ── Appel Sortant ──
      // On lance le timeout d'appel manqué (45 secondes)
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!_isCallActive) {
          socket.emit('webrtc_call_cancel', { 'toId': widget.otherId });
          socket.emit('webrtc_call_missed', { 
             'toId': widget.otherId,
             'type': widget.isVideoCall ? 'video' : 'audio',
             'conversationId': widget.conversationId
          });
          if (mounted) Navigator.pop(context);
        }
      });

      // Si le destinataire accepte
      socket.onCallAccepted((data) {
         if (mounted) {
            setState(() {
              _isCallActive = true;
              _timeoutTimer?.cancel();
              _audioPlayer.stop();
            });
            // Démarrer WebRTC handshake ici
         }
      });

      // Si le destinataire refuse
      socket.onCallRejected((data) {
         if (mounted) {
            _timeoutTimer?.cancel();
            _audioPlayer.stop();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appel refusé')));
         }
      });

    } else {
      // ── Appel Entrant ──
      // Si l'appelant annule avant qu'on décroche
      socket.onCallCancelled((data) {
         if (mounted) {
            _audioPlayer.stop();
            Navigator.pop(context);
         }
      });
    }
  }

  Future<void> _initRenderers() async {
    if (_isVideoEnabled) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      // L'initialisation réelle des flux WebRTC se fera via le contrôleur/service
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
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
    ref.read(socketServiceProvider).emit('webrtc_call_accept', {
      'callerId': widget.otherId,
    });
    // Démarrer WebRTC
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
    _audioPlayer.stop();
    final socket = ref.read(socketServiceProvider);
    
    if (!_isCallActive && !widget.isIncoming) {
       socket.emit('webrtc_call_cancel', { 'toId': widget.otherId });
       socket.emit('webrtc_call_missed', { 
         'toId': widget.otherId,
         'type': widget.isVideoCall ? 'video' : 'audio',
         'conversationId': widget.conversationId
       });
    } else {
       socket.emit('webrtc_call_ended', { 'toId': widget.otherId });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Couleur "Bleu OLI" sombre pour l'overlay
    final Color oliBlueOverlay = const Color(0xFF0D47A1).withOpacity(0.85);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Arrière-plan flouté ──
          if (widget.otherAvatarUrl != null && widget.otherAvatarUrl!.isNotEmpty && !_isVideoEnabled)
            Image.network(
              widget.otherAvatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black), // Fond noir si pas d'avatar ou vidéo
            
          // Filtre de flou et couleur Bleu OLI
          if (!_isVideoEnabled)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                color: oliBlueOverlay,
              ),
            ),

          // ── 2. Flux Vidéo (si applicable) ──
          if (_isVideoEnabled)
            RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            
          // Miniature locale pour appel vidéo
          if (_isVideoEnabled)
            Positioned(
              right: 20,
              bottom: 150,
              width: 100,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // ── 3. Informations de l'appel (Nom, Statut, Avatar) ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Statut de l'appel
                Text(
                  widget.isIncoming ? "Appel entrant..." : "Sonnerie...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                // Nom de l'utilisateur
                Text(
                  widget.otherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                // Avatar (caché si flux vidéo actif)
                if (!_isVideoEnabled)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: AutoRefreshAvatar(
                      avatarUrl: widget.otherAvatarUrl,
                      size: 140,
                    ),
                  ),
                  
                const Spacer(),
                
                // ── 4. Contrôles (Boutons du bas) ──
                if (widget.isIncoming && !_isCallActive) ...[
                  // BOUTONS DÉCROCHER / RACCROCHER POUR APPEL ENTRANT
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Refuser (Rouge)
                        GestureDetector(
                          onTap: _rejectCall,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 15)]
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                          ),
                        ),
                        // Accepter (Vert)
                        GestureDetector(
                          onTap: _acceptCall,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.green, blurRadius: 15)]
                            ),
                            child: const Icon(Icons.call, color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // BOUTONS DE CONTRÔLE STANDARDS (Appel en cours ou appelant)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        isActive: _isSpeakerOn,
                        onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      ),
                      if (widget.isVideoCall)
                        _buildControlButton(
                          icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          isActive: _isVideoEnabled,
                          onTap: () => setState(() => _isVideoEnabled = !_isVideoEnabled),
                        ),
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        isActive: _isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      // Bouton Raccrocher (Rouge vif)
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 1)
                            ]
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF0D47A1) : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
