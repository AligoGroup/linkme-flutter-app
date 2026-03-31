class PlatformPolicy {
  final String code; // PRIVACY / TESTING
  final String title;
  final String content;
  final bool enabled;

  const PlatformPolicy({required this.code, required this.title, required this.content, required this.enabled});

  factory PlatformPolicy.fromJson(Map json) {
    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
      }
      return false;
    }
    return PlatformPolicy(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      enabled: toBool(json['enabled']),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'content': content,
        'enabled': enabled,
      };
}
