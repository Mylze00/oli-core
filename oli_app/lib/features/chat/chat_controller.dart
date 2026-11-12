import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, Text;
import '../../main.dart' show globalNavigatorKey;
import 'widgets/progressive_chat_image.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../config/api_config.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/user/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'socket_service.dart';
import '../../core/services/database_helper.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../../core/services/hive_cache_service.dart'; // fallback
import '../../core/router/network/dio_provider.dart';

/// Texte laissé à la place d'un message supprimé pour tous (le même que celui du serveur).
const kDeletedMessagePlaceholder = '🚫 Message supprimé';

/// Délais de modification et de suppression pour tous, alignés sur le serveur.
const kMessageEditWindow = Duration(minutes: 15);
const kMessageDeleteForAllWindow = Duration(hours: 48);
const kMaxForwardRecipients = 5;

/// Un message en cours d'envoi n'a pas encore d'identifiant serveur.
/// Durées proposées pour les messages éphémères, avec la clé attendue par le serveur.
const kEphemeralDurations = <String, int?>{
  'off': null,
  '24h': 24 * 60 * 60,
  '7d': 7 * 24 * 60 * 60,
  '90d': 90 * 24 * 60 * 60,
};

String ephemeralLabel(int? seconds) => switch (seconds) {
      null => 'Désactivés',
      86400 => '24 heures',
      604800 => '7 jours',
      7776000 => '90 jours',
      _ => '${(seconds / 86400).round()} jours',
    };

/// Un message éphémère dont l'heure est passée n'est plus affiché, même depuis le cache.
bool isMessageExpired(Map<String, dynamic> message) {
  final expiresAt = DateTime.tryParse(message['expires_at']?.toString() ?? '');
  return expiresAt != null && expiresAt.isBefore(DateTime.now());
}

bool isServerMessageId(Object? id) => id != null && RegExp(r'^\d+$').hasMatch(id.toString());

class ChatState {
  final bool isLoading;
  final List<Map<String, dynamic>> messages;
  final int? conversationId;
  final String? error;
  final String? friendshipStatus;
  final int? requesterId;

  ChatState({
    this.isLoading = true, 
    this.messages = const [], 
    this.conversationId,
    this.error,
    this.friendshipStatus,
    this.requesterId,
    this.isOtherUserOnline = false,
    this.isOtherUserTyping = false,
    this.isOtherUserRecording = false,
    this.ephemeralSeconds,
    this.hasMoreOlder = true,
    this.isLoadingOlder = false,
  });

  /// Des messages plus anciens restent à charger sur le serveur (défilement vers le haut).
  final bool hasMoreOlder;
  final bool isLoadingOlder;

  /// Durée de vie des nouveaux messages (null = messages éphémères désactivés).
  final int? ephemeralSeconds;

  final bool isOtherUserOnline;
  final bool isOtherUserTyping;
  final bool isOtherUserRecording;

  ChatState copyWith({
    bool? isLoading, 
    List<Map<String, dynamic>>? messages, 
    int? conversationId,
    String? error,
    String? friendshipStatus,
    int? requesterId,
    bool? isOtherUserOnline,
    bool? isOtherUserTyping,
    bool? isOtherUserRecording,
    Object? ephemeralSeconds = _keep,
    bool? hasMoreOlder,
    bool? isLoadingOlder,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      error: error,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      requesterId: requesterId ?? this.requesterId,
      isOtherUserOnline: isOtherUserOnline ?? this.isOtherUserOnline,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
      isOtherUserRecording: isOtherUserRecording ?? this.isOtherUserRecording,
      ephemeralSeconds: identical(ephemeralSeconds, _keep) ? this.ephemeralSeconds : ephemeralSeconds as int?,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    );
  }
}

/// Distingue « ne pas changer » de « remettre à null » dans copyWith.
const _keep = Object();

final chatControllerProvider = StateNotifierProvider.family<ChatController, ChatState, String>((ref, otherUserId) {
  final user = ref.watch(userProvider).value;
  final socketService = ref.watch(socketServiceProvider);
  return ChatController(otherUserId, user?.id.toString(), socketService, ref);
});

class ChatController extends StateNotifier<ChatState> {
  int _loadRun = 0;
  final String otherUserId;
  final String? myId;
  final SocketService _socketService;
  final Ref _ref;
  Dio get _dio => _ref.read(dioProvider);
  final _storage = SecureStorageService();
  VoidCallback? _socketUnsubscribe;
  VoidCallback? _typingUnsubscribe;
  String? _productId;

  static const _uploadProgressStep = 0.02;
  static const _readReceiptDelay = Duration(milliseconds: 300);
  static const _typingRefreshInterval = Duration(seconds: 3);
  static const _typingIdleDelay = Duration(seconds: 4);
  static const _typingExpiryDelay = Duration(seconds: 7);

  DateTime? _lastTypingSentAt;
  Timer? _typingIdleTimer;
  Timer? _typingExpiryTimer;
  Timer? _readReceiptTimer;
  bool _isScreenActive = false;

  ChatController(this.otherUserId, this.myId, this._socketService, this._ref) : super(ChatState()) {
    _initChat();
  }

  Future<void> _initChat() async {
    if (myId == null) {
      state = state.copyWith(isLoading: false, error: "Non connecté");
      return;
    }

    try {
      // Connecter le socket et écouter les nouveaux messages
      await _socketService.connect(myId!);
      _socketUnsubscribe = _socketService.onMessage(_handleNewMessage);
      
      // Écouter les reçus de lecture
      _socketService.on('messages_read', _handleMessagesRead);
      _socketService.on('messages_delivered', _handleMessagesDelivered);
      _socketService.on('message_played', _handleMessagePlayed);
      _socketService.on('message_edited', _handleMessageEdited);
      _socketService.on('message_deleted', _handleMessageDeleted);
      _socketService.on('reaction_updated', _handleReactionUpdated);
      _socketService.on('conversation_ephemeral', _handleEphemeralChanged);
      
      // Écouter le statut en ligne (global ou spécifique)
      _socketService.on('user_online', _handleUserOnline);

      // Écouter le typing
      _typingUnsubscribe = _socketService.onUserTyping(_handleUserTyping);
      
      // Charger les messages depuis le backend
      await loadMessages();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    final senderId = data['sender_id']?.toString();

    if (senderId == otherUserId && state.isOtherUserTyping) {
      _typingExpiryTimer?.cancel();
      state = state.copyWith(isOtherUserTyping: false, isOtherUserRecording: false);
    }
    
    // Vérifier si le message nous concerne
    if (senderId == otherUserId || senderId == myId) {
      // Un message d'une autre conversation avec cette personne n'a pas sa place ici
      final incomingConversation = data['conversation_id'] ?? data['conversationId'];
      if (incomingConversation != null &&
          state.conversationId != null &&
          incomingConversation.toString() != state.conversationId.toString()) {
        return;
      }

      final incomingId = data['id']?.toString();
      
      // 1. Déduplication stricte par ID (String vs Int fix)
      final existingIds = state.messages.map((m) => m['id']?.toString()).toSet();
      if (incomingId != null && existingIds.contains(incomingId)) {
        return; 
      }

      // 2. Gestion Optimiste : Remplacement du message temporaire par le réel
      if (senderId == myId) {
        // On cherche un message temporaire avec le même contenu ET qui est récent (pour éviter les faux positifs)
        final pendingIndex = state.messages.lastIndexWhere((m) {
          final isOptimistic = m['id'] != null && m['id'].toString().startsWith('temp_');
          // Comparaison simple sur le contenu. Idéalement on utiliserait un UUID temporaire envoyé au back.
          return isOptimistic && m['content'] == data['content'];
        });

        if (pendingIndex != -1) {
          final newMessages = List<Map<String, dynamic>>.from(state.messages);
          newMessages[pendingIndex] = data; // Remplacement in-place
          state = state.copyWith(messages: newMessages);
          return;
        }
      }

      // Sinon, ajout normal
      final newMessages = [...state.messages, data];
      state = state.copyWith(messages: newMessages);
      _forceCacheUpdate(newMessages);
      if (senderId == otherUserId) _scheduleReadReceipt();
    }
  }

  void _handleMessagesRead(dynamic rawData) {
    if (!mounted || rawData is! Map<String, dynamic>) return;
    final data = rawData;
    
    // Si l'autre utilisateur a lu la conversation
    if (data['conversation_id'].toString() == state.conversationId.toString() && data['reader_id'].toString() == otherUserId) {
      // On marque tous NOS messages comme lus
      final updatedMessages = state.messages.map((m) {
        if (m['sender_id'].toString() == myId && (m['is_read'] == false || m['is_read'] == null)) {
          return {...m, 'is_read': true};
        }
        return m;
      }).toList();
      
      state = state.copyWith(messages: updatedMessages);
      _forceCacheUpdate(updatedMessages);
    }
  }

  void _setMessagePlayed(String messageId, String playedAt) {
    state = state.copyWith(messages: [
      for (final m in state.messages)
        if (m['id']?.toString() == messageId) {...m, 'played_at': playedAt} else m,
    ]);
  }

  void _handleMessagePlayed(dynamic rawData) {
    if (!mounted || rawData is! Map<String, dynamic>) return;
    _setMessagePlayed(rawData['message_id'].toString(), rawData['played_at']?.toString() ?? DateTime.now().toIso8601String());
  }

  /// Première écoute d'un vocal reçu : l'expéditeur en est prévenu.
  Future<void> markVoicePlayed(String messageId) async {
    if (messageId.startsWith('temp_')) return;
    _setMessagePlayed(messageId, DateTime.now().toIso8601String());
    try {
      final token = await _storage.getToken();
      await _dio.post(
        '${ApiConfig.baseUrl}/chat/messages/$messageId/played',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('❌ Écoute du vocal non transmise: $e');
    }
  }

  void _handleMessagesDelivered(dynamic rawData) {
    if (!mounted || rawData is! Map<String, dynamic>) return;
    if (rawData['conversation_id'].toString() != state.conversationId.toString() ||
        rawData['recipient_id'].toString() != otherUserId) {
      return;
    }

    final deliveredAt = DateTime.now().toIso8601String();
    state = state.copyWith(messages: [
      for (final m in state.messages)
        if (m['sender_id'].toString() == myId && m['delivered_at'] == null)
          {...m, 'delivered_at': deliveredAt}
        else
          m,
    ]);
  }

  /// Appelé par la page : un message n'est lu que si la discussion est réellement à l'écran.
  void setScreenActive(bool isActive) {
    _isScreenActive = isActive;
    if (isActive) {
      _scheduleReadReceipt();
    } else {
      _readReceiptTimer?.cancel();
    }
  }

  bool _isUnreadFromOther(Map<String, dynamic> message) =>
      message['sender_id'].toString() == otherUserId && message['is_read'] != true;

  void _scheduleReadReceipt() {
    if (!_isScreenActive) return;
    _readReceiptTimer?.cancel();
    _readReceiptTimer = Timer(_readReceiptDelay, _sendReadReceipt);
  }

  Future<void> _sendReadReceipt() async {
    final conversationId = state.conversationId;
    if (!mounted || !_isScreenActive || conversationId == null || !state.messages.any(_isUnreadFromOther)) return;

    try {
      final token = await _storage.getToken();
      await _dio.post(
        '${ApiConfig.baseUrl}/chat/conversations/$conversationId/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      state = state.copyWith(messages: [
        for (final m in state.messages)
          if (_isUnreadFromOther(m)) {...m, 'is_read': true} else m,
      ]);
    } catch (e) {
      debugPrint('❌ Accusé de lecture non envoyé: $e');
    }
  }

  void _handleUserOnline(dynamic data) {
    if (data is Map && data['userId'].toString() == otherUserId) {
      state = state.copyWith(isOtherUserOnline: data['online'] == true);
    }
  }

  void _handleUserTyping(Map<String, dynamic> data) {
    if (!mounted || data['userId']?.toString() != otherUserId) return;

    final conversationId = data['conversationId'];
    if (conversationId != null &&
        state.conversationId != null &&
        conversationId.toString() != state.conversationId.toString()) {
      return;
    }

    final isTyping = data['isTyping'] == true;
    _typingExpiryTimer?.cancel();
    if (isTyping) {
      // L'indicateur s'efface seul si l'autre personne perd sa connexion
      _typingExpiryTimer = Timer(_typingExpiryDelay, () {
        if (mounted) state = state.copyWith(isOtherUserTyping: false, isOtherUserRecording: false);
      });
    }
    state = state.copyWith(
      isOtherUserTyping: isTyping,
      isOtherUserRecording: isTyping && data['activity'] == 'recording',
    );
  }

  /// Le signal n'est répété que toutes les 3 secondes, pas à chaque touche.
  void sendTyping(bool isTyping) {
    _typingIdleTimer?.cancel();

    if (!isTyping) {
      if (_lastTypingSentAt != null) {
        _lastTypingSentAt = null;
        _emitTyping(false);
      }
      return;
    }

    final now = DateTime.now();
    if (_lastTypingSentAt == null || now.difference(_lastTypingSentAt!) >= _typingRefreshInterval) {
      _lastTypingSentAt = now;
      _emitTyping(true);
    }
    _typingIdleTimer = Timer(_typingIdleDelay, () => sendTyping(false));
  }

  /// Répété régulièrement pendant l'enregistrement, qui peut durer plusieurs minutes.
  void sendRecording(bool isRecording) {
    if (state.conversationId == null) return;
    _socketService.emit('typing', {
      'conversationId': state.conversationId,
      'isTyping': isRecording,
      'activity': 'recording',
    });
  }

  void _emitTyping(bool isTyping) {
    if (state.conversationId != null) {
      _socketService.emit('typing', {
        'conversationId': state.conversationId,
        'isTyping': isTyping,
      });
    }
  }

  void _forceCacheUpdate(List<Map<String, dynamic>> updatedMessages) async {
    if (updatedMessages.isEmpty) return;
    
    try {
      final db = await DatabaseHelper.instance.database;
      final batch = db.batch();
      
      for (var msg in updatedMessages) {
        if (msg['id'] != null && msg['id'].toString().startsWith('temp_')) continue;
        
        batch.insert('messages', {
          'message_id': msg['id']?.toString() ?? '',
          'conversation_id': msg['conversation_id'] ?? state.conversationId,
          'sender_id': msg['sender_id']?.toString() ?? '',
          'receiver_id': msg['receiver_id']?.toString() ?? '',
          'content': msg['content'] ?? '',
          'type': msg['type'] ?? 'text',
          'created_at': msg['created_at'] ?? '',
          'raw_data': jsonEncode(msg),
        }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      }
      
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('⚠️ Erreur _forceCacheUpdate SQLite: $e');
    }
  }

  /// Ouvre la conversation d'un produit, ou la discussion privée sans produit.
  Future<void> openConversation({String? productId}) async {
    _productId = productId;
    state = ChatState(isOtherUserOnline: state.isOtherUserOnline);
    await Future.wait([loadMessages(), _loadPresence()]);
  }

  Future<void> _loadPresence() async {
    try {
      final token = await _storage.getToken();
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chat/presence/$otherUserId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        state = state.copyWith(isOtherUserOnline: response.data['online'] == true);
      }
    } catch (e) {
      debugPrint('Présence indisponible: $e');
    }
  }

  Future<void> loadMessages({String? productId}) async {
    _productId = productId ?? _productId;
    // Seul le dernier chargement demandé peut remplir l'écran
    final run = ++_loadRun;
    
    try {
      final token = await _storage.getToken();
      
      String url = '${ApiConfig.baseUrl}/chat/messages/$otherUserId';
      url += _productId != null ? '?productId=$_productId' : '?scope=private';
      
      // [CACHE] 1. Lecture rapide du cache SQLite
      try {
        final db = await DatabaseHelper.instance.database;
        final maps = await db.query(
          'messages',
          where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
          whereArgs: [myId, otherUserId, otherUserId, myId],
          // Ouverture rapide : seulement les messages récents (les plus anciens se
          // chargent en remontant, via loadOlder)
          orderBy: 'created_at DESC',
          limit: 200,
        );
        
        if (maps.isNotEmpty) {
          final messages = maps.reversed.map((m) {
            final raw = jsonDecode(m['raw_data'] as String);
            return Map<String, dynamic>.from(raw);
          }).where((m) => m['product_id']?.toString() == _productId).toList();
          
          int? convId;
          if (messages.isNotEmpty) {
            convId = messages.first['conversation_id'];
          }
          
          state = state.copyWith(
            isLoading: false,
            messages: messages,
            conversationId: convId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lecture SQLite messages: $e');
      }

      // 2. Rafraîchissement en arrière-plan
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (run != _loadRun) return;

      if (response.statusCode == 200) {
        final data = response.data;
        final messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        
        int? convId;
        String? friendshipStatus;
        int? requesterId;
        
        if (messages.isNotEmpty) {
          convId = messages.first['conversation_id'];
          friendshipStatus = messages.first['friendship_status'];
          requesterId = messages.first['requester_id'];
        }
        
        
        state = state.copyWith(
          isLoading: false,
          messages: messages,
          hasMoreOlder: messages.length >= _pageSize,
          conversationId: convId,
          friendshipStatus: friendshipStatus,
          requesterId: requesterId,
          ephemeralSeconds: messages.isEmpty ? state.ephemeralSeconds : (messages.last['ephemeral_seconds'] as num?)?.toInt(),
        );

        // [CACHE] 3. Mise à jour silencieuse du cache
        _forceCacheUpdate(messages);
      }
    } catch (e) {
      debugPrint('❌ Erreur loadMessages: $e');
      // Si on a déjà chargé le cache, on ne remplace pas par une erreur
      if (state.messages.isEmpty) {
        state = state.copyWith(isLoading: false, error: "Erreur de chargement: $e");
      }
    }
  }

  /// Taille d'une page de messages (même valeur que le serveur par défaut).
  static const _pageSize = 50;

  /// Charge les messages précédant le plus ancien affiché (défilement vers le haut),
  /// sans doublon ; la position de lecture est conservée par la liste inversée.
  Future<void> loadOlder() async {
    if (state.isLoadingOlder || !state.hasMoreOlder || state.isLoading) return;
    final oldestId = state.messages
        .map((m) => int.tryParse('${m['id']}'))
        .whereType<int>()
        .fold<int?>(null, (min, id) => min == null || id < min ? id : min);
    if (oldestId == null) {
      state = state.copyWith(hasMoreOlder: false);
      return;
    }
    state = state.copyWith(isLoadingOlder: true);
    try {
      final token = await _storage.getToken();
      final scope = _productId != null ? 'productId=$_productId' : 'scope=private';
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chat/messages/$otherUserId?$scope&cursor=$oldestId&limit=$_pageSize',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final older = List<Map<String, dynamic>>.from(response.data['messages'] ?? []);
      final known = state.messages.map((m) => '${m['id']}').toSet();
      final fresh = older.where((m) => !known.contains('${m['id']}')).toList();
      state = state.copyWith(
        messages: [...fresh, ...state.messages],
        hasMoreOlder: older.length >= _pageSize,
        isLoadingOlder: false,
      );
    } catch (e) {
      debugPrint('⚠️ Messages plus anciens non chargés : $e');
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  /// Affiche le vocal tout de suite, puis l'envoie.
  Future<bool> sendVoice(
    XFile file, {
    required Duration duration,
    List<int> waveform = const [],
    String? replyToId,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
  }) async {
    if (myId == null) return false;

    const content = '🎤 Message vocal';
    final placeholderId = 'temp_upload_${DateTime.now().millisecondsSinceEpoch}';
    var lastProgress = 0.0;

    state = state.copyWith(messages: [
      ...state.messages,
      {
        'id': placeholderId,
        'sender_id': int.parse(myId!),
        'content': content,
        'type': 'audio',
        'created_at': DateTime.now().toIso8601String(),
        'local_audio': true,
        'duration_ms': duration.inMilliseconds,
        'waveform': waveform,
        'upload_progress': 0.0,
      },
    ]);

    final url = await uploadImage(file, onProgress: (progress) {
      if (!mounted || (progress - lastProgress < _uploadProgressStep && progress < 1)) return;
      lastProgress = progress;
      state = state.copyWith(messages: [
        for (final m in state.messages)
          if (m['id'] == placeholderId) {...m, 'upload_progress': progress} else m,
      ]);
    });

    if (!mounted) return url != null;
    state = state.copyWith(messages: state.messages.where((m) => m['id'] != placeholderId).toList());
    if (url == null) return false;

    sendMessage(
      content: content,
      mediaUrl: url,
      mediaType: 'audio',
      type: 'audio',
      customMetadata: {'duration_ms': duration.inMilliseconds, 'waveform': waveform},
      replyToId: replyToId,
      productId: productId,
      productName: productName,
      productImage: productImage,
      productPrice: productPrice,
    );
    return true;
  }

  /// Affiche l'image tout de suite, puis l'affine au fil de l'envoi.
  Future<bool> sendImage(
    XFile file, {
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
  }) async {
    if (myId == null) return false;

    final bytes = await file.readAsBytes();
    final placeholderId = 'temp_upload_${DateTime.now().millisecondsSinceEpoch}';
    var lastProgress = 0.0;

    state = state.copyWith(messages: [
      ...state.messages,
      {
        'id': placeholderId,
        'sender_id': int.parse(myId!),
        'content': '',
        'type': 'media',
        'created_at': DateTime.now().toIso8601String(),
        'local_image': bytes,
        'upload_progress': 0.0,
      },
    ]);

    final url = await uploadImage(file, onProgress: (progress) {
      if (!mounted || (progress - lastProgress < _uploadProgressStep && progress < 1)) return;
      lastProgress = progress;
      state = state.copyWith(messages: [
        for (final m in state.messages)
          if (m['id'] == placeholderId) {...m, 'upload_progress': progress} else m,
      ]);
    });

    if (!mounted) return url != null;
    state = state.copyWith(messages: state.messages.where((m) => m['id'] != placeholderId).toList());
    if (url == null) return false;

    SentImageCache.put(url, bytes);
    sendMessage(
      content: '',
      mediaUrl: url,
      mediaType: 'image',
      productId: productId,
      productName: productName,
      productImage: productImage,
      productPrice: productPrice,
    );
    return true;
  }

  Future<String?> uploadImage(XFile file, {void Function(double progress)? onProgress}) async {
    try {
      final token = await _storage.getToken();
      
      final fileName = file.name;
      final fileBytes = await file.readAsBytes();
      final mimeType = file.mimeType;

      FormData formData = FormData.fromMap({
        'chat_file': MultipartFile.fromBytes(
          fileBytes, 
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      });

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      if (response.statusCode == 200) {
        return response.data['mediaUrl']; 
      }
    } catch (e) {
      debugPrint('❌ Erreur uploadImage: $e');
    }
    return null;
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? mediaType,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
    Map<String, dynamic>? customMetadata,
    String? replyToId,
    double? latitude,
    double? longitude,
  }) async {
    // Si pas de contenu, pas de média, et pas de metadata custom, on n'envoie rien
    if ((content.trim().isEmpty && mediaUrl == null && customMetadata == null) || myId == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Ajout Optimiste Immédiat
    final optimisticMessage = {
      'id': tempId,
      'sender_id': int.parse(myId!),
      'content': content.isEmpty && mediaUrl != null 
          ? (mediaType == 'image' ? '📷 Image' : '📎 Fichier') 
          : (type == 'location' ? '📍 Position partagée' : content),
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'metadata': jsonEncode({
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaUrl != null) 'mediaType': mediaType ?? 'file',
        ...?customMetadata,
      })
    };
    
    // On ajoute tout de suite
    state = state.copyWith(messages: [...state.messages, optimisticMessage]);

    try {
      final token = await _storage.getToken();
      
      dynamic data;
      String url;

      final Map<String, dynamic> metadata = {
          if (productName != null) 'product_name': productName,
          if (productImage != null) 'product_image': productImage,
          if (productPrice != null) 'product_price': productPrice,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (mediaUrl != null) 'mediaType': mediaType ?? 'file',
          ...?customMetadata,
      };

      if (state.conversationId == null) {
        url = '${ApiConfig.baseUrl}/chat/send';
        data = {
          'recipientId': int.tryParse(otherUserId),
          'content': content,
          'type': type,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'productId': productId != null ? int.tryParse(productId) : null,
          'metadata': metadata,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        };
      } else {
        url = '${ApiConfig.baseUrl}/chat/messages';
        data = {
          'conversationId': state.conversationId,
          'recipientId': int.tryParse(otherUserId),
          'content': content,
          'type': type,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'metadata': metadata,
          if (replyToId != null) 'replyToId': int.tryParse(replyToId),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        };
      }

      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final resData = response.data;
        // Mise à jour des infos de conversation si c'est le premier message
        if (state.conversationId == null) {
          state = state.copyWith(
            conversationId: resData['conversationId'],
            friendshipStatus: resData['friendship_status'],
            requesterId: resData['requester_id'],
          );
        }

        // La réponse confirme l'envoi, même si l'événement en direct n'arrive pas
        final savedMessage = resData['message'];
        if (mounted && savedMessage is Map && state.messages.any((m) => m['id'] == tempId)) {
          final alreadyReceived = state.messages.any((m) => m['id']?.toString() == savedMessage['id']?.toString());
          state = state.copyWith(messages: [
            for (final m in state.messages)
              if (m['id'] != tempId)
                m
              else if (!alreadyReceived)
                Map<String, dynamic>.from(savedMessage),
          ]);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur sendMessage: $e');
      final errorData = e is DioException ? e.response?.data : null;
      if (errorData is Map && const {'you_blocked', 'blocked_by_recipient'}.contains(errorData['code'])) {
        final context = globalNavigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(errorData['error'].toString())),
          );
        }
      }
      state = state.copyWith(
        // On ne met PAS de state.error global car cela remplace toute la liste des messages
        // par l'icône d'erreur (ce qui était le bug d'UI).
        // On se contente de retirer le message temporaire.
        messages: state.messages.where((m) => m['id'] != tempId).toList(), 
      );
    }
  }

  // ─── Modifier, supprimer, transférer ──────────────────────────────────────

  bool _isThisConversation(Object? conversationId) =>
      conversationId != null && conversationId.toString() == state.conversationId?.toString();

  void _updateMessages(List<Map<String, dynamic>> messages) {
    state = state.copyWith(messages: messages);
    _forceCacheUpdate(messages);
  }

  void _updateMessage(String messageId, Map<String, dynamic> Function(Map<String, dynamic> message) update) {
    _updateMessages([
      for (final m in state.messages)
        if (m['id']?.toString() == messageId) update(m) else m,
    ]);
  }

  Map<String, dynamic> _asDeleted(Map<String, dynamic> message, String deletedAt) => {
        ...message,
        'content': kDeletedMessagePlaceholder,
        'metadata': {'deleted': true},
        'reactions': null,
        'deleted_at': deletedAt,
      };

  String _serverError(Object error, String fallback) {
    final data = error is DioException ? error.response?.data : null;
    return data is Map && data['error'] != null ? data['error'].toString() : fallback;
  }

  void _handleMessageEdited(dynamic data) {
    if (!mounted || data is! Map<String, dynamic> || !_isThisConversation(data['conversation_id'])) return;
    _updateMessage(data['message_id'].toString(), (m) => {
          ...m,
          'content': data['content'],
          'edited_at': data['edited_at'],
        });
  }

  void _handleMessageDeleted(dynamic data) {
    if (!mounted || data is! Map<String, dynamic> || !_isThisConversation(data['conversation_id'])) return;
    final deletedAt = data['deleted_at']?.toString() ?? DateTime.now().toUtc().toIso8601String();
    _updateMessage(data['message_id'].toString(), (m) => _asDeleted(m, deletedAt));
  }

  void _handleReactionUpdated(dynamic data) {
    if (!mounted || data is! Map<String, dynamic> || !_isThisConversation(data['conversation_id'])) return;
    _updateMessage(data['message_id'].toString(), (m) => {...m, 'reactions': data['reactions']});
  }

  void _handleEphemeralChanged(dynamic data) {
    if (!mounted || data is! Map<String, dynamic> || !_isThisConversation(data['conversation_id'])) return;
    state = state.copyWith(ephemeralSeconds: (data['ephemeral_seconds'] as num?)?.toInt());
  }

  /// Règle la durée des messages éphémères pour les deux participants.
  Future<String?> setEphemeral(String durationKey) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return 'Envoyez un premier message pour régler cette discussion';
    try {
      final response = await _dio.put(
        '${ApiConfig.baseUrl}/chat/conversations/$conversationId/ephemeral',
        data: {'duration': durationKey},
      );
      state = state.copyWith(ephemeralSeconds: (response.data['ephemeral_seconds'] as num?)?.toInt());
      return null;
    } catch (e) {
      return _serverError(e, "Le réglage n'a pas pu être enregistré");
    }
  }

  /// Renvoie un message d'erreur à afficher, ou null si la modification a réussi.
  Future<String?> editMessage(String messageId, String content) async {
    final text = content.trim();
    if (text.isEmpty) return 'Le message ne peut pas être vide';
    final previous = state.messages;
    _updateMessage(messageId, (m) => {...m, 'content': text, 'edited_at': DateTime.now().toUtc().toIso8601String()});
    try {
      await _dio.patch('${ApiConfig.baseUrl}/chat/messages/$messageId', data: {'content': text});
      return null;
    } catch (e) {
      if (mounted) _updateMessages(previous);
      return _serverError(e, "Le message n'a pas pu être modifié");
    }
  }

  /// Pour moi : le message disparaît de ma discussion. Pour tous : son contenu est effacé chez les deux.
  Future<String?> deleteMessage(String messageId, {required bool forAll}) async {
    final previous = state.messages;
    if (forAll) {
      _updateMessage(messageId, (m) => _asDeleted(m, DateTime.now().toUtc().toIso8601String()));
    } else {
      _updateMessages(state.messages.where((m) => m['id']?.toString() != messageId).toList());
    }
    try {
      await _dio.delete(
        '${ApiConfig.baseUrl}/chat/messages/$messageId',
        queryParameters: {'for': forAll ? 'all' : 'me'},
      );
      return null;
    } catch (e) {
      if (mounted) _updateMessages(previous);
      return _serverError(e, "Le message n'a pas pu être supprimé");
    }
  }

  /// Le serveur recopie le message dans chaque discussion choisie.
  Future<String?> forwardMessage(String messageId, List<String> conversationIds) async {
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/chat/messages/$messageId/forward',
        data: {'conversationIds': conversationIds.map(int.parse).toList()},
      );
      return null;
    } catch (e) {
      return _serverError(e, "Le message n'a pas pu être transféré");
    }
  }

  /// Ajouter ou retirer une réaction sur un message
  Future<void> reactToMessage(String messageId, String emoji) async {
    // Mise à jour optimiste locale
    final updatedMessages = state.messages.map((m) {
      if (m['id']?.toString() == messageId) {
        final rawReactions = m['reactions'];
        Map<String, dynamic> reactions = {};
        if (rawReactions != null) {
          try {
            reactions = rawReactions is String
                ? Map<String, dynamic>.from(jsonDecode(rawReactions))
                : Map<String, dynamic>.from(rawReactions);
          } catch (_) {}
        }

        // Toggle logic: si déjà présent par cet user, retirer
        // (simplifié : on incrémente/décrémente le compteur global)
        final current = (reactions[emoji] as num?)?.toInt() ?? 0;
        if (current > 0) {
          reactions[emoji] = current - 1;
          if (reactions[emoji] == 0) reactions.remove(emoji);
        } else {
          reactions[emoji] = current + 1;
        }
        return {...m, 'reactions': reactions};
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updatedMessages);
    _forceCacheUpdate(updatedMessages);

    // Appel backend
    try {
      final token = await _storage.getToken();
      await _dio.put(
        '${ApiConfig.baseUrl}/chat/messages/$messageId/react',
        data: {'emoji': emoji},
        options: Options(headers: {'Authorization': 'Bearer \$token'}),
      );
    } catch (e) {
      debugPrint('❌ Erreur reactToMessage: \$e');
      // On ne rollback pas pour ne pas perturber l'UX
    }
  }

  @override
  void dispose() {
    _socketUnsubscribe?.call();
    _typingUnsubscribe?.call();
    _typingIdleTimer?.cancel();
    _typingExpiryTimer?.cancel();
    _readReceiptTimer?.cancel();
    super.dispose();
  }
}