/// Community Notification model
/// Types:
/// - publish: user published an article successfully
/// - like: someone liked my article or my comment under an article
/// - reply: someone commented on my article or replied to my comment
class CommunityNotification {
  final String id; // unique (local) id
  final CommunityNotificationType type;
  final int articleId;
  final String articleTitle;
  final String articleImageUrl; // cover image
  final DateTime createdAt;

  // User who triggered it (for like/reply)
  final String? fromUserName;
  final String? fromUserAvatar;

  // For like/reply on a comment
  final int? commentId; // comment id for deep-link/scrolling
  final String? commentText; // the comment text (when like target is a comment, or reply content)
  final bool likeTargetIsComment; // only meaningful for type==like
  final bool isReply; // for comment/reply notifications: true=回复, false=评论

  final bool read;

  const CommunityNotification({
    required this.id,
    required this.type,
    required this.articleId,
    required this.articleTitle,
    required this.articleImageUrl,
    required this.createdAt,
    this.fromUserName,
    this.fromUserAvatar,
    this.commentId,
    this.commentText,
    this.likeTargetIsComment = false,
    this.isReply = false,
    this.read = false,
  });

  CommunityNotification copyWith({
    String? id,
    CommunityNotificationType? type,
    int? articleId,
    String? articleTitle,
    String? articleImageUrl,
    DateTime? createdAt,
    String? fromUserName,
    String? fromUserAvatar,
    int? commentId,
    String? commentText,
    bool? likeTargetIsComment,
    bool? isReply,
    bool? read,
  }) => CommunityNotification(
        id: id ?? this.id,
        type: type ?? this.type,
        articleId: articleId ?? this.articleId,
        articleTitle: articleTitle ?? this.articleTitle,
        articleImageUrl: articleImageUrl ?? this.articleImageUrl,
        createdAt: createdAt ?? this.createdAt,
        fromUserName: fromUserName ?? this.fromUserName,
        fromUserAvatar: fromUserAvatar ?? this.fromUserAvatar,
        commentId: commentId ?? this.commentId,
        commentText: commentText ?? this.commentText,
        likeTargetIsComment: likeTargetIsComment ?? this.likeTargetIsComment,
        isReply: isReply ?? this.isReply,
        read: read ?? this.read,
      );

  factory CommunityNotification.fromJson(Map<String, dynamic> json) => CommunityNotification(
        id: json['id'] as String,
        type: _parseType(json['type'] as String?),
        articleId: (json['articleId'] as num).toInt(),
        articleTitle: (json['articleTitle'] ?? '').toString(),
        articleImageUrl: (json['articleImageUrl'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
        fromUserName: (json['fromUserName'])?.toString(),
        fromUserAvatar: (json['fromUserAvatar'])?.toString(),
        commentId: (json['commentId'] as num?)?.toInt(),
        commentText: (json['commentText'])?.toString(),
        likeTargetIsComment: (json['likeTargetIsComment'] as bool?) ?? false,
        isReply: (json['isReply'] as bool?) ?? false,
        read: (json['read'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'articleId': articleId,
        'articleTitle': articleTitle,
        'articleImageUrl': articleImageUrl,
        'createdAt': createdAt.toIso8601String(),
        'fromUserName': fromUserName,
        'fromUserAvatar': fromUserAvatar,
        'commentId': commentId,
        'commentText': commentText,
        'likeTargetIsComment': likeTargetIsComment,
        'isReply': isReply,
        'read': read,
      };

  static CommunityNotificationType _parseType(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'publish':
        return CommunityNotificationType.publish;
      case 'like':
        return CommunityNotificationType.like;
      case 'reply':
        return CommunityNotificationType.reply;
      default:
        return CommunityNotificationType.publish;
    }
  }
}

enum CommunityNotificationType { publish, like, reply }
