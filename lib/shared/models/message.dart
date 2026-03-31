class Message {
  final int id;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final int? receiverId;
  final int? groupId;
  final String content;
  final MessageType type;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isRead;
  final bool isPinned;
  final int? pinnedById;
  final DateTime? pinnedAt;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImage;
  final DateTime createdAt;
  
  // shared/models/message.dart | 通话卡片相关字段 | 用于存储通话消息的通话信息
  final String? callRoomUuid;
  final String? callType; // VOICE 或 VIDEO
  final String? callResult; // COMPLETED, MISSED, REJECTED, CANCELLED, BUSY, FAILED
  final int? callDurationSeconds;
  
  // 发送状态（仅前端本地使用，不参与后端序列化）
  final MessageSendStatus? sendStatus; // sending/failedOffline/failedServer/sent
  
  // Reply threading (optional)
  final int? replyToMessageId; // id of the message being replied to
  final int? replyToSenderId;
  final String? replyToSenderName;
  final String? replyToPreview; // short preview text of replied message
  final DateTime? replyToCreatedAt; // timestamp of the replied message
  
  // 情绪监测相关字段
  final bool hasEmotionAlert;
  final String? emotionTipText;
  final bool isThirdEmotionKeyword; // 是否是第三次情绪关键词消息

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.receiverId,
    this.groupId,
    required this.content,
    required this.type,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isRead = false,
    this.isPinned = false,
    this.pinnedById,
    this.pinnedAt,
    this.linkTitle,
    this.linkDescription,
    this.linkImage,
    required this.createdAt,
    this.sendStatus,
    String? conversationId,
    
    // 通话卡片相关参数
    this.callRoomUuid,
    this.callType,
    this.callResult,
    this.callDurationSeconds,
    
    // 情绪监测相关参数
    this.hasEmotionAlert = false,
    this.emotionTipText,
    this.isThirdEmotionKeyword = false,
    
    // Reply threading
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToSenderName,
    this.replyToPreview,
    this.replyToCreatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // 处理sender对象或senderId
    int senderId;
    String senderName;
    String? senderAvatar;
    
    if (json['sender'] is Map<String, dynamic>) {
      final sender = json['sender'] as Map<String, dynamic>;
      senderId = (sender['id'] as num).toInt();
      senderName = sender['nickname'] ?? sender['username'] ?? 'Unknown';
      senderAvatar = sender['avatar'];
    } else {
      senderId = (json['senderId'] as num).toInt();
      senderName = json['senderName'] ?? 'Unknown';
      senderAvatar = json['senderAvatar'];
    }

    // 处理receiver对象或receiverId
    int? receiverId;
    if (json['receiver'] is Map<String, dynamic>) {
      receiverId = ((json['receiver'] as Map<String, dynamic>)['id'] as num).toInt();
    } else if (json['receiverId'] != null) {
      receiverId = (json['receiverId'] as num).toInt();
    }

    // 处理group对象或groupId
    int? groupId;
    if (json['group'] is Map<String, dynamic>) {
      groupId = ((json['group'] as Map<String, dynamic>)['id'] as num).toInt();
    } else if (json['groupId'] != null) {
      groupId = (json['groupId'] as num).toInt();
    }

    // 解析回复引用（后端可能返回 replyTo 或 replyToMessage 字段）
    int? replyToMessageId;
    int? replyToSenderId;
    String? replyToSenderName;
    String? replyToPreview;
    DateTime? replyToCreatedAtLocal;
    final replyJson = (json['replyTo'] ?? json['replyToMessage']);
    if (replyJson is Map<String, dynamic>) {
      replyToMessageId = (replyJson['id'] as num?)?.toInt();
      // 解析发送者信息
      if (replyJson['sender'] is Map<String, dynamic>) {
        final s = replyJson['sender'] as Map<String, dynamic>;
        replyToSenderId = (s['id'] as num?)?.toInt();
        replyToSenderName = s['nickname'] ?? s['username'] ?? '对方';
      } else if (replyJson['senderId'] != null) {
        replyToSenderId = (replyJson['senderId'] as num?)?.toInt();
      }
      replyToPreview = replyJson['content'] as String?;
      if (replyJson['createdAt'] != null) {
        try {
          replyToCreatedAtLocal = DateTime.parse(replyJson['createdAt']);
        } catch (_) {}
      }
    }

    return Message(
      id: (json['id'] as num).toInt(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      groupId: groupId,
      content: json['content'] as String? ?? '',
      type: () {
        final parsedType = _parseMessageType(json['type']);
        print('Message.fromJson: id=${json['id']}, type原始值=${json['type']}, 解析后=${parsedType}');
        return parsedType;
      }(),
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'] != null ? (json['fileSize'] as num).toInt() : null,
      isRead: json['isRead'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedById: json['pinnedBy'] is Map<String, dynamic> 
        ? ((json['pinnedBy'] as Map<String, dynamic>)['id'] as num).toInt()
        : json['pinnedBy'] != null ? (json['pinnedBy'] as num).toInt() : null,
      pinnedAt: json['pinnedAt'] != null ? DateTime.parse(json['pinnedAt']) : null,
      linkTitle: json['linkTitle'],
      linkDescription: json['linkDescription'],
      linkImage: json['linkImage'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      // 本地字段不从后端反序列化
      sendStatus: _parseSendStatus(json['sendStatus']),
      
      // shared/models/message.dart | fromJson | 通话卡片字段解析
      callRoomUuid: json['callRoomUuid'],
      callType: json['callType'],
      callResult: json['callResult'],
      callDurationSeconds: json['callDurationSeconds'] != null ? (json['callDurationSeconds'] as num).toInt() : null,
      
      // 情绪监测字段解析
      hasEmotionAlert: json['hasEmotionAlert'] as bool? ?? false,
      emotionTipText: json['emotionTipText'],
      isThirdEmotionKeyword: json['isThirdEmotionKeyword'] as bool? ?? false,
      // 回复相关
      replyToMessageId: replyToMessageId,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      replyToPreview: replyToPreview,
      replyToCreatedAt: replyToCreatedAtLocal,
    );
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    final typeStr = type.toString().toUpperCase();
    switch (typeStr) {
      case 'TEXT':
        return MessageType.text;
      case 'IMAGE':
        return MessageType.image;
      case 'VOICE':
        return MessageType.voice;
      case 'FILE':
        return MessageType.file;
      case 'AUDIO':
        return MessageType.audio;
      case 'VIDEO':
        return MessageType.video;
      case 'LINK':
        return MessageType.link;
      case 'SYSTEM':
        return MessageType.system;
      case 'CALL':
        return MessageType.call;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'groupId': groupId,
      'content': content,
      'type': type.name.toUpperCase(),
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'isRead': isRead,
      'isPinned': isPinned,
      'pinnedBy': pinnedById,
      'pinnedAt': pinnedAt?.toIso8601String(),
      'linkTitle': linkTitle,
      'linkDescription': linkDescription,
      'linkImage': linkImage,
      'createdAt': createdAt.toIso8601String(),
      // sendStatus 为本地字段，不序列化到后端
      if (sendStatus != null) 'sendStatus': sendStatus!.name,
      
      // shared/models/message.dart | toJson | 通话卡片字段序列化
      if (callRoomUuid != null) 'callRoomUuid': callRoomUuid,
      if (callType != null) 'callType': callType,
      if (callResult != null) 'callResult': callResult,
      if (callDurationSeconds != null) 'callDurationSeconds': callDurationSeconds,
      
      // 情绪监测字段
      'hasEmotionAlert': hasEmotionAlert,
      'emotionTipText': emotionTipText,
      'isThirdEmotionKeyword': isThirdEmotionKeyword,
      // 回复引用（仅传基础字段，避免循环）
      if (replyToMessageId != null) 'replyTo': {
        'id': replyToMessageId,
        if (replyToSenderId != null) 'senderId': replyToSenderId,
        if (replyToSenderName != null) 'senderName': replyToSenderName,
        if (replyToPreview != null) 'content': replyToPreview,
        if (replyToCreatedAt != null) 'createdAt': replyToCreatedAt!.toIso8601String(),
      },
    };
  }

  Message copyWith({
    int? id,
    int? senderId,
    String? senderName,
    String? senderAvatar,
    int? receiverId,
    int? groupId,
    String? content,
    MessageType? type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    bool? isRead,
    bool? isPinned,
    int? pinnedById,
    DateTime? pinnedAt,
    String? linkTitle,
    String? linkDescription,
    String? linkImage,
    DateTime? createdAt,
    MessageSendStatus? sendStatus,
    
    // shared/models/message.dart | copyWith | 通话卡片字段
    String? callRoomUuid,
    String? callType,
    String? callResult,
    int? callDurationSeconds,
    
    // 情绪监测相关参数
    bool? hasEmotionAlert,
    String? emotionTipText,
    bool? isThirdEmotionKeyword,
    // 回复相关
    int? replyToMessageId,
    int? replyToSenderId,
    String? replyToSenderName,
    String? replyToPreview,
    DateTime? replyToCreatedAt,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      content: content ?? this.content,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
      pinnedById: pinnedById ?? this.pinnedById,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      linkTitle: linkTitle ?? this.linkTitle,
      linkDescription: linkDescription ?? this.linkDescription,
      linkImage: linkImage ?? this.linkImage,
      createdAt: createdAt ?? this.createdAt,
      sendStatus: sendStatus ?? this.sendStatus,
      
      // 通话卡片字段
      callRoomUuid: callRoomUuid ?? this.callRoomUuid,
      callType: callType ?? this.callType,
      callResult: callResult ?? this.callResult,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      
      // 情绪监测字段
      hasEmotionAlert: hasEmotionAlert ?? this.hasEmotionAlert,
      emotionTipText: emotionTipText ?? this.emotionTipText,
      isThirdEmotionKeyword: isThirdEmotionKeyword ?? this.isThirdEmotionKeyword,
      // 回复相关
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      replyToCreatedAt: replyToCreatedAt ?? this.replyToCreatedAt,
    );
  }

  bool isFromMe(int currentUserId) => senderId == currentUserId;

  bool get isGroup => groupId != null;

  // 兼容性getter
  String get conversationId {
    if (groupId != null) {
      return groupId.toString();
    } else if (receiverId != null) {
      return receiverId.toString();
    } else {
      return senderId.toString();
    }
  }

  DateTime get timestamp => createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum MessageType { text, image, voice, file, audio, video, link, system, call }

// 本地发送状态
enum MessageSendStatus { sending, failedOffline, failedServer, sent }

// 临时方法，实际应从状态管理中获取
int getCurrentUserId() => 0; // 占位符

MessageSendStatus? _parseSendStatus(dynamic value) {
  if (value == null) return null;
  final text = value.toString().toLowerCase();
  for (final status in MessageSendStatus.values) {
    if (status.name.toLowerCase() == text) {
      return status;
    }
  }
  return null;
}
