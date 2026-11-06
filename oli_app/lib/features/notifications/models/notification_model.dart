import 'package:flutter/material.dart';
/// Modèle de notification
class NotificationModel {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Copie avec modifications
  NotificationModel copyWith({
    int? id,
    int? userId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Emoji — conservé pour compatibilité (FCM, anciens écrans).
  String get icon {
    switch (type) {
      case 'message':
        return '💬';
      case 'call':
        return '📞';
      case 'order':
        return '📦';
      case 'wallet':
      case 'wallet_deposit':
        return '💰';
      case 'offer':
        return '🎉';
      case 'announcement':
        return '📢';
      case 'system':
        return '⚙️';
      default:
        return '🔔';
    }
  }

  /// Icône (style iOS : glyphe blanc sur pastille colorée arrondie).
  IconData get iconData {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'call':
        return Icons.phone_rounded;
      case 'order':
        return Icons.local_shipping_rounded;
      case 'wallet':
      case 'wallet_deposit':
        return Icons.account_balance_wallet_rounded;
      case 'offer':
        return Icons.local_offer_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'system':
        return Icons.settings_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Couleur de la pastille (palette iOS).
  Color get iconColor {
    switch (type) {
      case 'message':
        return const Color(0xFF34C759); // vert iOS
      case 'call':
        return const Color(0xFF007AFF); // bleu iOS
      case 'order':
        return const Color(0xFFFF9500); // orange iOS
      case 'wallet':
      case 'wallet_deposit':
        return const Color(0xFF30B0C7); // cyan iOS
      case 'offer':
        return const Color(0xFFAF52DE); // violet iOS
      case 'announcement':
        return const Color(0xFFFF3B30); // rouge iOS
      case 'system':
        return const Color(0xFF8E8E93); // gris iOS
      default:
        return const Color(0xFFFF3B30);
    }
  }

  /// Obtenir le temps relatif (ex: "Il y a 5 min")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Obtenir la date et l'heure formatées
  String get formattedDateTime {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '${day}/${month}/${year} à ${hour}:${minute}';
  }
}
