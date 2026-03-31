import 'dart:convert';

enum FavoriteType { message, link, text }

class Favorite {
  final int id;
  final int ownerId;
  final int? messageId;
  final int? targetUserId;
  final int? targetGroupId;
  final FavoriteType type;
  final String content;
  final String? url;
  final String? title;
  final String? description;
  final String? targetName;
  final String? targetAvatar;
  final String? extra;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.ownerId,
    this.messageId,
    this.targetUserId,
    this.targetGroupId,
    required this.type,
    required this.content,
    this.url,
    this.title,
    this.description,
    this.targetName,
    this.targetAvatar,
    this.extra,
    required this.createdAt,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: (json['id'] as num).toInt(),
      ownerId: (json['ownerId'] as num).toInt(),
      messageId: json['messageId'] != null ? (json['messageId'] as num).toInt() : null,
      targetUserId: json['targetUserId'] != null ? (json['targetUserId'] as num).toInt() : null,
      targetGroupId: json['targetGroupId'] != null ? (json['targetGroupId'] as num).toInt() : null,
      type: _parseFavoriteType(json['type']),
      content: json['content'] as String? ?? '',
      url: json['url'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      targetName: json['targetName'] as String?,
      targetAvatar: json['targetAvatar'] as String?,
      extra: json['extra'] as String?,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  static FavoriteType _parseFavoriteType(dynamic type) {
    if (type == null) return FavoriteType.message;
    final typeStr = type.toString().toUpperCase();
    switch (typeStr) {
      case 'MESSAGE':
        return FavoriteType.message;
      case 'LINK':
        return FavoriteType.link;
      case 'TEXT':
        return FavoriteType.text;
      default:
        return FavoriteType.message;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'messageId': messageId,
      'targetUserId': targetUserId,
      'targetGroupId': targetGroupId,
      'type': type.name.toUpperCase(),
      'content': content,
      'url': url,
      'title': title,
      'description': description,
      'targetName': targetName,
      'targetAvatar': targetAvatar,
      'extra': extra,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Favorite copyWith({
    int? id,
    int? ownerId,
    int? messageId,
    int? targetUserId,
    int? targetGroupId,
    FavoriteType? type,
    String? content,
    String? url,
    String? title,
    String? description,
    String? targetName,
    String? targetAvatar,
    String? extra,
    DateTime? createdAt,
  }) {
    return Favorite(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      type: type ?? this.type,
      content: content ?? this.content,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      targetName: targetName ?? this.targetName,
      targetAvatar: targetAvatar ?? this.targetAvatar,
      extra: extra ?? this.extra,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic>? _extraCache;
  Map<String, dynamic>? get extraData {
    if (extra == null || extra!.trim().isEmpty) return null;
    if (_extraCache != null) return _extraCache;
    try {
      _extraCache = jsonDecode(extra!) as Map<String, dynamic>;
    } catch (_) {
      _extraCache = null;
    }
    return _extraCache;
  }

  String? get senderName => extraData?['senderName'] as String?;
  String? get senderAvatar => extraData?['senderAvatar'] as String?;
  String? get conversationName =>
      targetName ?? extraData?['conversationName'] as String?;
  String? get conversationAvatar =>
      targetAvatar ?? extraData?['conversationAvatar'] as String?;

  bool get isGroupConversation =>
      (extraData?['conversationType'] ?? '').toString().toUpperCase() == 'GROUP' ||
      targetGroupId != null;

  DateTime? get messageTimestamp {
    final raw = extraData?['timestamp'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return createdAt;
  }

  String? get linkUrl {
    final data = extraData;
    if (data != null && data['linkUrl'] is String) {
      return data['linkUrl'] as String;
    }
    if (extra != null && extra!.startsWith('http')) return extra;
    return url;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Favorite && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
