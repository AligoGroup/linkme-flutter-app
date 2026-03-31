class QuickLink {
  final int id;
  final int userId;
  final int? peerUserId;
  final int? groupId;
  final String title;
  final String url;
  final String? color;
  final DateTime createdAt;

  QuickLink({
    required this.id,
    required this.userId,
    this.peerUserId,
    this.groupId,
    required this.title,
    required this.url,
    this.color,
    required this.createdAt,
  });

  factory QuickLink.fromJson(Map<String, dynamic> json) {
    return QuickLink(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      peerUserId: json['peerUserId'] != null ? (json['peerUserId'] as num).toInt() : null,
      groupId: json['groupId'] != null ? (json['groupId'] as num).toInt() : null,
      title: json['title'] as String,
      url: json['url'] as String,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'peerUserId': peerUserId,
      'groupId': groupId,
      'title': title,
      'url': url,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  QuickLink copyWith({
    int? id,
    int? userId,
    int? peerUserId,
    int? groupId,
    String? title,
    String? url,
    String? color,
    DateTime? createdAt,
  }) {
    return QuickLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      peerUserId: peerUserId ?? this.peerUserId,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      url: url ?? this.url,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickLink && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}