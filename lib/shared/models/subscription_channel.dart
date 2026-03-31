class SubscriptionChannel {
  final String id; // e.g. 'linkme'
  final String name; // 订阅号名称
  final String? description;
  final String? avatar; // optional image url
  final bool official;

  const SubscriptionChannel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    this.official = false,
  });

  factory SubscriptionChannel.fromJson(Map<String, dynamic> json) {
    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    return SubscriptionChannel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      official: toBool(json['official']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (avatar != null) 'avatar': avatar,
      'official': official,
    };
  }
}
