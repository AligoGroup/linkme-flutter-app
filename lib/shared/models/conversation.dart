import 'user.dart';
import 'message.dart';
import 'dart:convert';

enum ConversationType {
  private, // 私聊
  group,   // 群聊
}

class Conversation {
  final String id;
  final ConversationType type;
  final String name;
  final String? avatar;
  final List<User> participants;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime lastActivity;
  final bool isPinned;
  final bool isMuted;

  Conversation({
    required this.id,
    required this.type,
    required this.name,
    this.avatar,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.lastActivity,
    this.isPinned = false,
    this.isMuted = false,
    DateTime? lastMessageTime,
  });

  // 获取对话显示名称
  String displayNameForUser(int currentUserId) {
    if (type == ConversationType.group) {
      return name;
    } else {
      // 私聊时显示对方用户的昵称或用户名
      final otherUser = participants.firstWhere(
        (user) => user.id != currentUserId,
        orElse: () => participants.first,
      );
      return otherUser.nickname ?? otherUser.username;
    }
  }
  
  // 获取对话显示名称（兼容性方法，使用默认值）
  String get displayName {
    // 这个方法保留以兼容现有代码，但应该使用displayNameForUser
    if (type == ConversationType.group) {
      return name;
    } else {
      // 如果没有参与者，返回默认名称
      if (participants.isEmpty) {
        return name.isNotEmpty ? name : '未知用户';
      }
      // 返回第一个参与者的名称作为fallback
      final firstUser = participants.first;
      return firstUser.nickname ?? firstUser.username;
    }
  }

  // 获取对话头像
  String? displayAvatarForUser(int currentUserId) {
    if (type == ConversationType.group) {
      return avatar;
    } else {
      // 私聊时显示对方用户的头像
      final otherUser = participants.firstWhere(
        (user) => user.id != currentUserId,
        orElse: () => participants.first,
      );
      return otherUser.avatar;
    }
  }
  
  // 获取对话头像（兼容性方法，使用默认值）
  String? get displayAvatar {
    if (type == ConversationType.group) {
      return avatar;
    } else {
      // 如果没有参与者，返回null
      if (participants.isEmpty) {
        return null;
      }
      // 返回第一个参与者的头像作为fallback
      return participants.first.avatar;
    }
  }

  // 获取最后消息的显示文本
  String get lastMessageText {
    if (lastMessage == null) return '';
    // 优先识别“文章分享”这种JSON文本：{"type":"ARTICLE_SHARE", ...}
    String? _tryArticleSharePreview(String content) {
      try {
        final obj = (content.trim().startsWith('{')) ? content : '';
        if (obj.isEmpty) return null;
        final map = jsonDecode(obj);
        if (map is Map) {
          final t = (map['type'] ?? '').toString().toUpperCase();
          if (t == 'ARTICLE_SHARE' || t == 'HOT_ARTICLE_SHARE') {
            final title = (map['title'] ?? '').toString();
            if (title.isNotEmpty) return '[文章] $title';
            return '[文章]';
          }
        }
      } catch (_) {}
      return null;
    }

    switch (lastMessage!.type) {
      case MessageType.text:
        // 如果是分享文章的JSON，改为“[文章] 标题”
        final special = _tryArticleSharePreview(lastMessage!.content);
        if (special != null) return special;
        return lastMessage!.content;
      case MessageType.image:
        return '[图片]';
      case MessageType.voice:
        return '[语音]';
      case MessageType.link:
        // 链接消息：优先用后端提供的标题
        if ((lastMessage!.linkTitle ?? '').trim().isNotEmpty) {
          return '[链接] ${lastMessage!.linkTitle}';
        }
        // 如果content本身是文章分享JSON，也统一展示
        final special = _tryArticleSharePreview(lastMessage!.content);
        if (special != null) return special;
        return '[链接]';
      case MessageType.system:
        try {
          final map = jsonDecode(lastMessage!.content);
          if (map is Map && map['type'] == 'zennotes_invitation') {
            return '[邀请] ${map['inviterName']} 邀请您协作编辑 "${map['notebookTitle']}"';
          }
        } catch (_) {}
        return lastMessage!.content;
      case MessageType.call:
        // shared/models/conversation.dart | lastMessageText | 通话消息预览
        // 作用：显示通话类型、结果和时长，格式：[语音通话]未接听 或 [视频通话]-1:20:30
        final callType = lastMessage!.callType ?? 'VOICE';
        final callResult = lastMessage!.callResult ?? 'COMPLETED';
        final durationSeconds = lastMessage!.callDurationSeconds ?? 0;
        
        // 判断是否为未接听
        final isMissed = callResult == 'CANCELLED' || 
                         callResult == 'REJECTED' || 
                         callResult == 'MISSED';
        
        // 格式化通话时长（时:分:秒）
        String formatDuration(int seconds) {
          if (seconds < 60) {
            return '${seconds}秒';
          } else if (seconds < 3600) {
            final minutes = seconds ~/ 60;
            final secs = seconds % 60;
            return secs > 0 ? '$minutes分${secs}秒' : '$minutes分';
          } else {
            final hours = seconds ~/ 3600;
            final minutes = (seconds % 3600) ~/ 60;
            return minutes > 0 ? '$hours小时$minutes分' : '$hours小时';
          }
        }
        
        final callTypeText = callType == 'VIDEO' ? '视频通话' : '语音通话';
        
        if (isMissed) {
          return '[$callTypeText]未接听';
        } else {
          return '[$callTypeText]-通话时间：${formatDuration(durationSeconds)}';
        }
      default:
        return '[消息]';
    }
  }

  // 兼容性getter
  DateTime get lastMessageTime => lastMessage?.createdAt ?? lastActivity;

  // 获取时间显示格式
  String get timeDisplay {
    final now = DateTime.now();
    final diff = now.difference(lastActivity);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${lastActivity.hour.toString().padLeft(2, '0')}:${lastActivity.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return weekdays[lastActivity.weekday % 7];
    } else {
      return '${lastActivity.month}/${lastActivity.day}';
    }
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? avatar,
    List<User>? participants,
    Message? lastMessage,
    int? unreadCount,
    DateTime? lastActivity,
    bool? isPinned,
    bool? isMuted,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivity: lastActivity ?? this.lastActivity,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'name': name,
      'avatar': avatar,
      'participants': participants.map((user) => user.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'lastActivity': lastActivity.toIso8601String(),
      'isPinned': isPinned,
      'isMuted': isMuted,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      type: ConversationType.values.firstWhere(
        (type) => type.toString().split('.').last == json['type'],
      ),
      name: json['name'],
      avatar: json['avatar'],
      participants: (json['participants'] as List)
          .map((userJson) => User.fromJson(userJson))
          .toList(),
      lastMessage: json['lastMessage'] != null 
          ? Message.fromJson(json['lastMessage']) 
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      lastActivity: DateTime.parse(json['lastActivity']),
      isPinned: json['isPinned'] ?? false,
      isMuted: json['isMuted'] ?? false,
    );
  }
}
