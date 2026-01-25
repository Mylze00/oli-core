import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';


class ChatInputArea extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(String)? onAudioRecorded; // New callback
  final VoidCallback onShowTools;
  final Function(bool)? onTyping;

  const ChatInputArea({
    super.key,
    required this.onSendMessage,
    required this.onShowTools,
    this.onAudioRecorded,
    this.onTyping,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  
  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false; // For future "lock" feature if needed, currently used for visual state
  double _dragOffset = 0.0;
  DateTime? _startTime;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;
  String? _currentPath;

  // Animation for Mic scaling
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

  // --- AUDIO RECORDING ---

  Future<bool> _checkPermission() async {
     if (kIsWeb) return true; // Web asks on usage
     
     // Check mic permission
     if (await Permission.microphone.request().isGranted) {
       return true;
     }
     return false;
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission micro requise')));
        return;
      }

      String? path;
      if (!kIsWeb) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = '${appDir.path}/$fileName';
        path = _currentPath;
      } else {
        _currentPath = null; // Web handles path internally (Blob)
      }

      await _audioRecorder.start(
        const RecordConfig(),
        path: path ?? '',
      );

      setState(() {
        _isRecording = true;
        _startTime = DateTime.now();
        _recordDuration = Duration.zero;
        _dragOffset = 0.0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration = Duration(seconds: timer.tick);
        });
      });

      _animController.forward();
      // Haptic feedback could be added here
      
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_isRecording) return;

    _timer?.cancel();
    _animController.reverse();

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }

    setState(() {
      _isRecording = false;
      _dragOffset = 0.0;
    });

    if (cancel) {
      if (path != null) {
        try { File(path).delete().ignore(); } catch (_) {}
      }
    } else {
      // Logic: If duration is too short (< 1s), cancel it to avoid accidental taps
      if (_recordDuration.inMilliseconds < 800) {
         if (path != null) {
           try { File(path).delete().ignore(); } catch (_) {}
         }
         // Optional: Show "Hold to record" hint
      } else {
        if (path != null && widget.onAudioRecorded != null) {
          widget.onAudioRecorded!(path);
        }
      }
    }
  }

  void _updateDragOffset(double dx) {
    // We track horizontal drag. If user drags Left logic.
    setState(() {
      _dragOffset = dx;
    });
    
    // If dragged far enough to left, we could show visual "Cancel" state
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
    // Threshold to cancel
    final bool isCancelling = _dragOffset < -80; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
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
            // If Text: Show Add Button
            // If Recording: Hide Add Button
             if (!_isRecording)
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: theme.primaryColor, size: 28),
                onPressed: widget.onShowTools,
              ),

             // Main Content Area
             Expanded(
               child: _isRecording 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          _formatDuration(_recordDuration),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        if (isCancelling)
                           const Text("Relâcher pour annuler", style: TextStyle(color: Colors.red))
                        else
                           const Text("<< Glisser pour annuler", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
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
                ),
             ),
            
            const SizedBox(width: 8),

            // Send or Mic Button
            // If text -> Send Button (Tap)
            // If no text -> Mic Button (Long Press)
            if (hasText) 
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
            else
               GestureDetector(
                 onLongPressStart: (_) => _startRecording(),
                 onLongPressMoveUpdate: (details) => _updateDragOffset(details.offsetFromOrigin.dx),
                 onLongPressEnd: (details) {
                    bool shouldCancel = _dragOffset < -80; // Customizable threshold
                    _stopRecording(cancel: shouldCancel);
                 },
                 child: ScaleTransition(
                   scale: _scaleAnimation,
                   child: Container(
                      width: 48, 
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isRecording ? (isCancelling ? Colors.red : Colors.redAccent) : theme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)] : [],
                      ),
                      child: Icon(
                        _isRecording ? (isCancelling ? Icons.delete : Icons.mic) : Icons.mic, 
                        color: Colors.white, 
                        size: 24
                      ),
                    ),
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
