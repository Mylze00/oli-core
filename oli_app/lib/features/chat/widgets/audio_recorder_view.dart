import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class AudioRecorderView extends StatefulWidget {
  final Function(String path) onRecordComplete;
  final VoidCallback onCancel;

  const AudioRecorderView({
    super.key,
    required this.onRecordComplete,
    required this.onCancel,
  });

  @override
  State<AudioRecorderView> createState() => _AudioRecorderViewState();
}

class _AudioRecorderViewState extends State<AudioRecorderView> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _path;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        // Web doesn't support m4a recording well in all browsers (often webm/opus)
        // But the record package handles types relative to encoder.
        // Let's use a generic name, extension is handled by encoder usually.
        final String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _path = '${appDir.path}/$fileName';

        // Start recording to file
        await _audioRecorder.start(
          const RecordConfig(),
          path: _path!,
        );

        setState(() {
          _isRecording = true;
          _duration = Duration.zero;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _duration += const Duration(seconds: 1);
          });
        });
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint("Error starting upload: $e");
      widget.onCancel();
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (cancel) {
      if (path != null) File(path).delete().ignore();
      widget.onCancel();
    } else {
      if (path != null) widget.onRecordComplete(path);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _stopRecording(cancel: true),
              child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _stopRecording(cancel: false),
              ),
            )
          ],
        ),
      ),
    );
  }
}
