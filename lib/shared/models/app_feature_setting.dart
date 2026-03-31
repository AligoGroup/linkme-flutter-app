import 'dart:convert';

class AppFeatureSetting {
  final String featureKey;
  final String category;
  final bool enabled;
  final int sortOrder;
  final Map<String, dynamic>? metadata;
  final DateTime? updatedAt;

  const AppFeatureSetting({
    required this.featureKey,
    required this.category,
    required this.enabled,
    required this.sortOrder,
    this.metadata,
    this.updatedAt,
  });

  factory AppFeatureSetting.fromJson(Map<String, dynamic> json) {
    return AppFeatureSetting(
      featureKey: (json['featureKey'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      enabled: _parseBool(json['enabled']),
      sortOrder: _parseInt(json['sortOrder']),
      metadata: _parseMetadata(json['metadata']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featureKey': featureKey,
      'category': category,
      'enabled': enabled,
      'sortOrder': sortOrder,
      if (metadata != null) 'metadata': metadata,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // ignore parse errors
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }
}

class AppFeatureSnapshot {
  final List<AppFeatureSetting> nav;
  final List<AppFeatureSetting> modules;

  const AppFeatureSnapshot({
    required this.nav,
    required this.modules,
  });

  Map<String, dynamic> toJson() => {
        'nav': nav.map((e) => e.toJson()).toList(),
        'modules': modules.map((e) => e.toJson()).toList(),
      };
}
