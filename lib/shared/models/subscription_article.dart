class SubscriptionArticle {
  final String id;
  final String channelId;
  final String title;
  final String summary; // 摘要
  final String content; // 正文（纯文本演示）
  final String? cover; // 封面图片（可为空，使用占位）
  final DateTime publishedAt;
  final bool official;

  const SubscriptionArticle({
    required this.id,
    required this.channelId,
    required this.title,
    required this.summary,
    required this.content,
    this.cover,
    required this.publishedAt,
    this.official = true,
  });

  factory SubscriptionArticle.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      final s = v.toString();
      return DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    return SubscriptionArticle(
      id: (json['id'] ?? '').toString(),
      channelId: (json['channelId'] ?? json['accountId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      cover: json['cover'] ?? json['coverImage'],
      publishedAt: parseTime(json['publishedAt']),
      official: toBool(json['official']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'title': title,
      'summary': summary,
      'content': content,
      if (cover != null) 'cover': cover,
      'publishedAt': publishedAt.toIso8601String(),
      'official': official,
    };
  }
}
