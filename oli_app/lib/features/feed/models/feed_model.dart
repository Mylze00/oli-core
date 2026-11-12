/// Publication du Fil (avec compteurs et état pour l'utilisateur connecté).
class FeedPost {
  final int id;
  final int? authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorOliId;
  final bool authorVerified;
  final String? content;
  final String? mediaUrl;
  final String mediaType;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final int bookmarksCount;
  final int viewsCount;
  final bool isLikedByMe;
  final bool isRepostedByMe;
  final bool isBookmarkedByMe;
  final bool isMine;
  final DateTime createdAt;

  /// Post cité dans cette publication (« Citer »), ou null.
  final FeedPost? quotedPost;

  FeedPost({
    required this.id,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorOliId,
    this.authorVerified = false,
    this.content,
    this.mediaUrl,
    required this.mediaType,
    required this.likesCount,
    required this.commentsCount,
    this.repostsCount = 0,
    this.bookmarksCount = 0,
    this.viewsCount = 0,
    required this.isLikedByMe,
    this.isRepostedByMe = false,
    this.isBookmarkedByMe = false,
    this.isMine = false,
    required this.createdAt,
    this.quotedPost,
  });

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'],
      authorId: int.tryParse(json['author_id']?.toString() ?? ''),
      authorName: json['author_name'] ?? 'Utilisateur',
      authorAvatar: json['author_avatar'],
      authorOliId: json['author_oli_id']?.toString(),
      authorVerified: json['author_verified'] == true,
      content: json['content'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'] ?? 'text',
      likesCount: _int(json['likes_count']),
      commentsCount: _int(json['comments_count']),
      repostsCount: _int(json['reposts_count']),
      bookmarksCount: _int(json['bookmarks_count']),
      viewsCount: _int(json['views_count']),
      isLikedByMe: json['is_liked_by_me'] == true,
      isRepostedByMe: json['is_reposted_by_me'] == true,
      isBookmarkedByMe: json['is_bookmarked_by_me'] == true,
      isMine: json['is_mine'] == true,
      createdAt: DateTime.parse(json['created_at']),
      quotedPost: json['quoted_post'] is Map
          ? FeedPost.fromJson({
              'likes_count': 0,
              'comments_count': 0,
              'is_liked_by_me': false,
              ...Map<String, dynamic>.from(json['quoted_post']),
            })
          : null,
    );
  }

  /// Format renvoyé par le serveur (pour le cache local).
  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'author_name': authorName,
        'author_avatar': authorAvatar,
        'author_oli_id': authorOliId,
        'author_verified': authorVerified,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'reposts_count': repostsCount,
        'bookmarks_count': bookmarksCount,
        'views_count': viewsCount,
        'is_liked_by_me': isLikedByMe,
        'is_reposted_by_me': isRepostedByMe,
        'is_bookmarked_by_me': isBookmarkedByMe,
        'is_mine': isMine,
        'created_at': createdAt.toIso8601String(),
        if (quotedPost != null) 'quoted_post': quotedPost!.toJson(),
      };

  FeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    int? bookmarksCount,
    int? viewsCount,
    bool? isLikedByMe,
    bool? isRepostedByMe,
    bool? isBookmarkedByMe,
  }) {
    return FeedPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorOliId: authorOliId,
      authorVerified: authorVerified,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isRepostedByMe: isRepostedByMe ?? this.isRepostedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      isMine: isMine,
      createdAt: createdAt,
      quotedPost: quotedPost,
    );
  }
}
