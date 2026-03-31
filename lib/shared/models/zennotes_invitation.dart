/// zennotes_invitation.dart | ZenNotesInvitation | ZenNotes邀请通知模型
/// 用于存储和展示笔记本协作邀请信息
class ZenNotesInvitation {
  const ZenNotesInvitation({
    required this.id,
    required this.notebookId,
    required this.notebookTitle,
    required this.inviterId,
    required this.inviterName,
    required this.inviterAvatar,
    required this.permission,
    required this.invitedAt,
    this.isRead = false,
  });

  final String id; // 邀请记录ID
  final int notebookId; // 笔记本ID
  final String notebookTitle; // 笔记本标题
  final int inviterId; // 邀请人ID
  final String inviterName; // 邀请人昵称
  final String? inviterAvatar; // 邀请人头像
  final String permission; // 权限：EDITOR
  final DateTime invitedAt; // 邀请时间
  final bool isRead; // 是否已读

  /// 从WebSocket消息创建邀请对象
  /// zennotes_invitation.dart | ZenNotesInvitation | fromWebSocketMessage | data
  factory ZenNotesInvitation.fromWebSocketMessage(Map<String, dynamic> data) {
    return ZenNotesInvitation(
      id: data['invitationId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      notebookId: (data['notebookId'] as num).toInt(),
      notebookTitle: data['notebookTitle'] as String,
      inviterId: (data['inviterId'] as num).toInt(),
      inviterName: data['inviterName'] as String,
      inviterAvatar: data['inviterAvatar'] as String?,
      permission: data['permission'] as String? ?? 'EDITOR',
      invitedAt: data['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
      isRead: false,
    );
  }

  /// 从JSON创建邀请对象（本地缓存）
  /// zennotes_invitation.dart | ZenNotesInvitation | fromJson | json
  factory ZenNotesInvitation.fromJson(Map<String, dynamic> json) {
    return ZenNotesInvitation(
      id: json['id']?.toString() ?? '',
      notebookId: (json['notebookId'] as num).toInt(),
      notebookTitle: json['notebookTitle'] as String,
      inviterId: (json['inviterId'] as num).toInt(),
      inviterName: json['inviterName'] as String,
      inviterAvatar: json['inviterAvatar'] as String?,
      permission: json['permission'] as String? ?? 'EDITOR',
      invitedAt: DateTime.parse(json['invitedAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// 从服务器响应创建邀请对象
  /// zennotes_invitation.dart | ZenNotesInvitation | fromServerResponse | json,isRead
  factory ZenNotesInvitation.fromServerResponse(Map<String, dynamic> json,
      {bool isRead = false}) {
    return ZenNotesInvitation(
      id: json['id']?.toString() ?? '',
      notebookId: (json['notebookId'] as num).toInt(),
      notebookTitle: json['notebookTitle'] as String,
      inviterId: (json['inviterId'] as num).toInt(),
      inviterName: json['inviterName'] as String,
      inviterAvatar: json['inviterAvatar'] as String?,
      permission: json['permission'] as String? ?? 'EDITOR',
      invitedAt: json['invitedAt'] != null
          ? DateTime.parse(json['invitedAt'] as String)
          : DateTime.now(),
      isRead: isRead,
    );
  }

  /// 转换为JSON
  /// zennotes_invitation.dart | ZenNotesInvitation | toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notebookId': notebookId,
      'notebookTitle': notebookTitle,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviterAvatar': inviterAvatar,
      'permission': permission,
      'invitedAt': invitedAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// 复制并修改属性
  /// zennotes_invitation.dart | ZenNotesInvitation | copyWith
  ZenNotesInvitation copyWith({
    String? id,
    int? notebookId,
    String? notebookTitle,
    int? inviterId,
    String? inviterName,
    String? inviterAvatar,
    String? permission,
    DateTime? invitedAt,
    bool? isRead,
  }) {
    return ZenNotesInvitation(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      notebookTitle: notebookTitle ?? this.notebookTitle,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviterAvatar: inviterAvatar ?? this.inviterAvatar,
      permission: permission ?? this.permission,
      invitedAt: invitedAt ?? this.invitedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// 获取权限的中文显示
  /// zennotes_invitation.dart | ZenNotesInvitation | permissionText
  String get permissionText {
    switch (permission) {
      case 'OWNER':
        return '所有者';
      case 'EDITOR':
        return '编辑者';
      default:
        return '查看者';
    }
  }

  /// 获取时间显示格式
  /// zennotes_invitation.dart | ZenNotesInvitation | timeDisplay
  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(invitedAt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${invitedAt.month}月${invitedAt.day}日';
    }
  }
}
