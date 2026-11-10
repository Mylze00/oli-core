import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';

const _chunkSize = 6 * 1024 * 1024;
const _maxChunkAttempts = 5;

/// Lit la partie demandée du fichier à envoyer.
typedef ByteRangeReader = Stream<List<int>> Function(int start, int end);

/// Échec d'envoi dont le message peut être montré à l'utilisateur.
class UploadFailure implements Exception {
  final String message;
  final bool cancelled;

  const UploadFailure(this.message, {this.cancelled = false});
}

/// Envoi direct vers Cloudinary, découpé en morceaux.
/// Un morceau perdu est renvoyé seul, et un nouvel appel à [run] reprend où l'envoi s'est arrêté.
class ResumableUpload {
  final String kind;
  final String filename;
  final int length;
  final ByteRangeReader read;
  final Dio api;

  final Dio _cloud;
  late final String _uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$length';
  int _offset = 0;
  String? _url;
  Map<String, dynamic>? _params;
  String? _publicId;

  ResumableUpload({
    required this.kind,
    required this.filename,
    required this.length,
    required this.read,
    required this.api,
    Dio? cloud,
  }) : _cloud = cloud ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 3),
            ));

  /// Retourne l'identifiant Cloudinary du fichier une fois envoyé en entier.
  Future<String> run({
    required void Function(int sentBytes) onProgress,
    required CancelToken cancelToken,
  }) async {
    final finished = _publicId;
    if (finished != null) {
      onProgress(length);
      return finished;
    }

    await _requestTicket(cancelToken);

    while (_offset < length) {
      final end = (_offset + _chunkSize < length) ? _offset + _chunkSize : length;
      final chunk = await _readChunk(_offset, end);
      final response = await _sendChunk(chunk, _offset, end, onProgress, cancelToken);
      _offset = end;
      onProgress(_offset);
      if (_offset >= length) {
        final publicId = response['public_id']?.toString();
        if (publicId == null) {
          throw const UploadFailure("Le fichier n'a pas été enregistré. Réessayez.");
        }
        _publicId = publicId;
      }
    }
    return _publicId!;
  }

  Future<void> _requestTicket(CancelToken cancelToken) async {
    if (_params != null) return;
    try {
      final response = await api.post(
        '/api/videos/upload-ticket',
        data: {'kind': kind},
        cancelToken: cancelToken,
      );
      _url = response.data['upload_url'] as String;
      _params = Map<String, dynamic>.from(response.data['params'] as Map);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw const UploadFailure('Envoi annulé', cancelled: true);
      final data = e.response?.data;
      final message = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
      throw UploadFailure(message ?? "Impossible de préparer l'envoi. Vérifiez votre connexion.");
    }
  }

  Future<Uint8List> _readChunk(int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final part in read(start, end)) {
      builder.add(part);
    }
    return builder.takeBytes();
  }

  Future<Map<String, dynamic>> _sendChunk(
    Uint8List chunk,
    int start,
    int end,
    void Function(int sentBytes) onProgress,
    CancelToken cancelToken,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final form = FormData.fromMap({
          ..._params!,
          'file': MultipartFile.fromBytes(chunk, filename: filename),
        });
        final response = await _cloud.post(
          _url!,
          data: form,
          cancelToken: cancelToken,
          options: Options(headers: {
            'X-Unique-Upload-Id': _uniqueId,
            'Content-Range': 'bytes $start-${end - 1}/$length',
          }),
          onSendProgress: (sent, total) {
            if (total > 0) onProgress(start + (chunk.length * sent / total).floor());
          },
        );
        return Map<String, dynamic>.from(response.data as Map);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          throw const UploadFailure('Envoi annulé', cancelled: true);
        }
        final status = e.response?.statusCode ?? 0;
        if (status >= 400 && status < 500) {
          throw UploadFailure(_cloudMessage(e));
        }
        if (attempt >= _maxChunkAttempts) {
          throw const UploadFailure('La connexion a été interrompue. Appuyez sur Réessayer pour reprendre.');
        }
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  String _cloudMessage(DioException e) {
    final data = e.response?.data;
    final detail = data is Map && data['error'] is Map ? data['error']['message']?.toString() : null;
    if (detail != null && detail.toLowerCase().contains('format')) {
      return "Ce format de fichier n'est pas accepté.";
    }
    return "Le fichier a été refusé. Essayez avec une autre vidéo.";
  }
}
