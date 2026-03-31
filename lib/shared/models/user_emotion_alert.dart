class UserEmotionAlert {
  final int id;
  final int userId;
  final int friendId;
  final int keywordCount;
  final DateTime? lastTriggerTime;
  final AlertLevel alertLevel;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserEmotionAlert({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.keywordCount,
    this.lastTriggerTime,
    required this.alertLevel,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserEmotionAlert.fromJson(Map<String, dynamic> json) {
    return UserEmotionAlert(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      friendId: (json['friendId'] as num).toInt(),
      keywordCount: (json['keywordCount'] as num).toInt(),
      lastTriggerTime: json['lastTriggerTime'] != null 
        ? DateTime.parse(json['lastTriggerTime']) 
        : null,
      alertLevel: _parseAlertLevel(json['alertLevel']),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  static AlertLevel _parseAlertLevel(dynamic level) {
    if (level == null) return AlertLevel.low;
    final levelStr = level.toString().toLowerCase();
    switch (levelStr) {
      case 'high':
        return AlertLevel.high;
      case 'medium':
        return AlertLevel.medium;
      case 'low':
      default:
        return AlertLevel.low;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'keywordCount': keywordCount,
      'lastTriggerTime': lastTriggerTime?.toIso8601String(),
      'alertLevel': alertLevel.name.toUpperCase(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 获取警告级别对应的文本
  String get alertLevelText {
    switch (alertLevel) {
      case AlertLevel.high:
        return '高级警告';
      case AlertLevel.medium:
        return '中级警告';
      case AlertLevel.low:
        return '轻微提醒';
    }
  }

  /// 获取情绪提示文本
  String get emotionTipText {
    return '请及时关注好友情绪状态';
  }
  
  /// 获取弹窗说明文本
  String get alertExplanation {
    return '系统监测到该好友在与多名用户聊天中提及强烈消极情绪，为避免自杀行为执行，建议及时关注和疏导！';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserEmotionAlert && 
           other.id == id &&
           other.userId == userId &&
           other.friendId == friendId;
  }

  @override
  int get hashCode => Object.hash(id, userId, friendId);
}

enum AlertLevel { low, medium, high }