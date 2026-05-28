class FeedPost {
  final int id;
  final String authorName;
  final String? authorAvatar;
  final String? content;
  final String? mediaUrl;
  final String mediaType;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final DateTime createdAt;

  FeedPost({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    this.content,
    this.mediaUrl,
    required this.mediaType,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    required this.createdAt,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'],
      authorName: json['author_name'] ?? 'Utilisateur',
      authorAvatar: json['author_avatar'],
      content: json['content'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'] ?? 'text',
      likesCount: int.tryParse(json['likes_count']?.toString() ?? '0') ?? 0,
      commentsCount: int.tryParse(json['comments_count']?.toString() ?? '0') ?? 0,
      isLikedByMe: json['is_liked_by_me'] == true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  FeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
  }) {
    return FeedPost(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }
}
