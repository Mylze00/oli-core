import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../../core/router/network/dio_provider.dart';
import '../services/resumable_upload.dart';
import 'video_feed_provider.dart';

const _doneBannerDuration = Duration(seconds: 4);

enum VideoPublishStatus { idle, uploading, finalizing, failed, done }

/// Fichiers et informations d'une vidéo à publier.
class VideoPublishJob {
  final XFile file;
  final int length;
  final PlatformFile? sound;
  final String? title;
  final String? description;
  final String? productId;

  const VideoPublishJob({
    required this.file,
    required this.length,
    this.sound,
    this.title,
    this.description,
    this.productId,
  });
}

class VideoPublishState {
  final VideoPublishStatus status;
  final double progress;
  final String? error;
  final Uint8List? thumbnail;
  final bool inBackground;

  const VideoPublishState({
    this.status = VideoPublishStatus.idle,
    this.progress = 0,
    this.error,
    this.thumbnail,
    this.inBackground = false,
  });

  /// Une publication occupe l'application tant qu'elle n'est ni terminée ni abandonnée.
  bool get isActive =>
      status == VideoPublishStatus.uploading ||
      status == VideoPublishStatus.finalizing ||
      status == VideoPublishStatus.failed;

  VideoPublishState copyWith({
    VideoPublishStatus? status,
    double? progress,
    String? error,
    bool? inBackground,
  }) {
    return VideoPublishState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
      thumbnail: thumbnail,
      inBackground: inBackground ?? this.inBackground,
    );
  }
}

/// Publie une vidéo indépendamment de l'écran affiché.
class VideoPublishNotifier extends StateNotifier<VideoPublishState> {
  final Ref _ref;
  final Dio? _cloud;

  VideoPublishJob? _job;
  CancelToken? _cancelToken;
  ResumableUpload? _videoUpload;
  ResumableUpload? _soundUpload;
  Timer? _dismissTimer;

  VideoPublishNotifier(this._ref, {Dio? cloud})
      : _cloud = cloud,
        super(const VideoPublishState());

  /// Lance une publication, sauf si une autre est déjà en cours.
  void start(VideoPublishJob job, {Uint8List? thumbnail}) {
    if (state.isActive) return;
    _dismissTimer?.cancel();
    _job = job;
    _videoUpload = null;
    _soundUpload = null;
    state = VideoPublishState(status: VideoPublishStatus.uploading, thumbnail: thumbnail);
    unawaited(_run());
  }

  /// Reprend après une erreur, depuis le dernier morceau reçu.
  void retry() {
    if (_job == null || state.status != VideoPublishStatus.failed) return;
    state = state.copyWith(status: VideoPublishStatus.uploading);
    unawaited(_run());
  }

  void cancel() {
    final token = _cancelToken;
    if (state.status == VideoPublishStatus.failed || token == null || token.isCancelled) {
      dismiss();
      return;
    }
    token.cancel();
  }

  void sendToBackground() {
    if (state.isActive) state = state.copyWith(error: state.error, inBackground: true);
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _job = null;
    _videoUpload = null;
    _soundUpload = null;
    state = const VideoPublishState();
  }

  ResumableUpload _uploadFor({
    required String kind,
    required String filename,
    required int length,
    required ByteRangeReader read,
  }) {
    return ResumableUpload(
      kind: kind,
      filename: filename,
      length: length,
      read: read,
      api: _ref.read(dioProvider),
      cloud: _cloud,
    );
  }

  Future<void> _run() async {
    final job = _job!;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final sound = job.sound;
    final soundLength = sound?.size ?? 0;
    final totalBytes = job.length + soundLength;

    void report(int sent) {
      if (mounted && state.status == VideoPublishStatus.uploading) {
        state = state.copyWith(progress: (sent / totalBytes).clamp(0.0, 1.0));
      }
    }

    try {
      String? soundPublicId;
      if (sound != null) {
        final bytes = sound.bytes!;
        _soundUpload ??= _uploadFor(
          kind: 'audio',
          filename: sound.name,
          length: soundLength,
          read: (start, end) => Stream.value(bytes.sublist(start, end)),
        );
        soundPublicId = await _soundUpload!.run(onProgress: report, cancelToken: cancelToken);
      }

      _videoUpload ??= _uploadFor(
        kind: 'video',
        filename: job.file.name,
        length: job.length,
        read: job.file.openRead,
      );
      final videoPublicId = await _videoUpload!.run(
        onProgress: (sent) => report(soundLength + sent),
        cancelToken: cancelToken,
      );

      state = state.copyWith(status: VideoPublishStatus.finalizing, progress: 1);
      await _ref.read(dioProvider).post(
        '/api/videos',
        cancelToken: cancelToken,
        data: {
          'video_public_id': videoPublicId,
          if (soundPublicId != null) 'audio_public_id': soundPublicId,
          if (job.title != null && job.title!.isNotEmpty) 'title': job.title,
          if (job.description != null && job.description!.isNotEmpty) 'description': job.description,
          if (job.productId != null) 'product_id': job.productId,
        },
      );

      await _onPublished();
    } on UploadFailure catch (e) {
      if (e.cancelled) {
        dismiss();
      } else {
        state = state.copyWith(status: VideoPublishStatus.failed, error: e.message);
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        dismiss();
        return;
      }
      final data = e.response?.data;
      state = state.copyWith(
        status: VideoPublishStatus.failed,
        error: (data is Map ? (data['message'] ?? data['error'])?.toString() : null) ??
            "La publication n'a pas abouti. Vérifiez votre connexion et réessayez.",
      );
    }
  }

  Future<void> _onPublished() async {
    final inBackground = state.inBackground;
    _job = null;
    state = state.copyWith(status: VideoPublishStatus.done, progress: 1);

    if (!kIsWeb) {
      // Le nettoyage du cache ne doit jamais remettre en cause une publication réussie
      unawaited(VideoCompress.deleteAllCache().catchError((Object error) {
        debugPrint('Cache de compression non vidé: $error');
        return null;
      }));
    }
    _ref.invalidate(creatorProfileProvider);

    if (inBackground) {
      unawaited(_ref.read(videoFeedProvider.notifier).loadFeed());
      _dismissTimer = Timer(_doneBannerDuration, dismiss);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final videoPublishProvider =
    StateNotifierProvider<VideoPublishNotifier, VideoPublishState>((ref) => VideoPublishNotifier(ref));
