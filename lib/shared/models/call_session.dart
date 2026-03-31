/// shared/models/call_session.dart | CallSession | 通话会话模型
/// 作用：定义音视频通话相关的数据模型
/// 包括：通话类型、房间状态、参与者信息等

/// 通话类型枚举
enum CallType {
  voice,  // 语音通话
  video,  // 视频通话
}

/// 房间类型枚举
enum CallRoomType {
  private,  // 私聊通话
  group,    // 群聊通话
}

/// 房间状态枚举
enum CallRoomStatus {
  waiting,   // 等待中
  ringing,   // 响铃中
  active,    // 通话中
  ended,     // 已结束
}

/// 参与者状态枚举
enum CallParticipantStatus {
  invited,   // 已邀请
  ringing,   // 响铃中
  joined,    // 已加入
  left,      // 已离开
  rejected,  // 已拒绝
  timeout,   // 超时
  busy,      // 忙线
}

/// 通话结果枚举
enum CallResult {
  completed,  // 正常完成
  missed,     // 未接听
  rejected,   // 被拒绝
  cancelled,  // 已取消
  busy,       // 忙线
  failed,     // 失败
}


/// 用户简要信息
class CallUserInfo {
  final int id;
  final String? username;
  final String? nickname;
  final String? avatar;
  
  CallUserInfo({
    required this.id,
    this.username,
    this.nickname,
    this.avatar,
  });
  
  /// shared/models/call_session.dart | CallUserInfo.fromJson | 从JSON解析用户信息
  factory CallUserInfo.fromJson(Map<String, dynamic> json) {
    return CallUserInfo(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String?,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'avatar': avatar,
  };
  
  /// 获取显示名称（优先昵称）
  String get displayName => nickname ?? username ?? '用户$id';
}

/// 群聊简要信息
class CallGroupInfo {
  final int id;
  final String? name;
  final String? avatar;
  
  CallGroupInfo({
    required this.id,
    this.name,
    this.avatar,
  });
  
  /// shared/models/call_session.dart | CallGroupInfo.fromJson | 从JSON解析群聊信息
  factory CallGroupInfo.fromJson(Map<String, dynamic> json) {
    return CallGroupInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
  };
}


/// 通话房间
class CallRoom {
  final String roomUuid;
  final CallType callType;
  final CallRoomType roomType;
  final CallRoomStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final CallUserInfo? caller;
  final CallGroupInfo? group;
  final List<CallParticipant> participants;
  
  CallRoom({
    required this.roomUuid,
    required this.callType,
    required this.roomType,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.caller,
    this.group,
    this.participants = const [],
  });
  
  /// shared/models/call_session.dart | CallRoom.fromJson | 从JSON解析通话房间
  factory CallRoom.fromJson(Map<String, dynamic> json) {
    return CallRoom(
      roomUuid: json['roomUuid'] as String,
      callType: _parseCallType(json['callType']),
      roomType: _parseRoomType(json['roomType']),
      status: _parseRoomStatus(json['status']),
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt']) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      caller: json['caller'] != null 
          ? CallUserInfo.fromJson(json['caller']) 
          : null,
      group: json['group'] != null 
          ? CallGroupInfo.fromJson(json['group']) 
          : null,
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => CallParticipant.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'roomUuid': roomUuid,
    'callType': callType.name.toUpperCase(),
    'roomType': roomType.name.toUpperCase(),
    'status': status.name.toUpperCase(),
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'caller': caller?.toJson(),
    'group': group?.toJson(),
    'participants': participants.map((p) => p.toJson()).toList(),
  };
}

/// 通话参与者
class CallParticipant {
  final int userId;
  final CallUserInfo? user;
  final CallParticipantStatus status;
  final bool audioEnabled;
  final bool videoEnabled;
  final bool screenSharing;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  
  CallParticipant({
    required this.userId,
    this.user,
    required this.status,
    this.audioEnabled = true,
    this.videoEnabled = false,
    this.screenSharing = false,
    this.joinedAt,
    this.leftAt,
  });
  
  /// 获取头像
  String? get avatar => user?.avatar;
  
  /// 获取显示名称
  String get displayName => user?.displayName ?? '用户$userId';
  
  /// shared/models/call_session.dart | CallParticipant.fromJson | 从JSON解析参与者
  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      userId: (json['userId'] as num).toInt(),
      user: json['user'] != null 
          ? CallUserInfo.fromJson(json['user']) 
          : null,
      status: _parseParticipantStatus(json['status']),
      audioEnabled: json['audioEnabled'] as bool? ?? true,
      videoEnabled: json['videoEnabled'] as bool? ?? false,
      screenSharing: json['screenSharing'] as bool? ?? false,
      joinedAt: json['joinedAt'] != null 
          ? DateTime.parse(json['joinedAt']) 
          : null,
      leftAt: json['leftAt'] != null 
          ? DateTime.parse(json['leftAt']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'user': user?.toJson(),
    'status': status.name.toUpperCase(),
    'audioEnabled': audioEnabled,
    'videoEnabled': videoEnabled,
    'screenSharing': screenSharing,
    'joinedAt': joinedAt?.toIso8601String(),
    'leftAt': leftAt?.toIso8601String(),
  };
}

/// 通话记录
class CallRecord {
  final int id;
  final String roomUuid;
  final CallType callType;
  final CallRoomType roomType;
  final CallResult result;
  final int durationSeconds;
  final int maxParticipants;
  final int totalParticipants;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final CallUserInfo? peer;
  final CallGroupInfo? group;
  final bool isCaller;
  
  CallRecord({
    required this.id,
    required this.roomUuid,
    required this.callType,
    required this.roomType,
    required this.result,
    this.durationSeconds = 0,
    this.maxParticipants = 0,
    this.totalParticipants = 0,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.peer,
    this.group,
    this.isCaller = false,
  });
  
  /// shared/models/call_session.dart | CallRecord.fromJson | 从JSON解析通话记录
  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: (json['id'] as num).toInt(),
      roomUuid: json['roomUuid'] as String,
      callType: _parseCallType(json['callType']),
      roomType: _parseRoomType(json['roomType']),
      result: _parseCallResult(json['result']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 0,
      totalParticipants: (json['totalParticipants'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
      endedAt: json['endedAt'] != null 
          ? DateTime.parse(json['endedAt']) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      peer: json['peer'] != null 
          ? CallUserInfo.fromJson(json['peer']) 
          : null,
      group: json['group'] != null 
          ? CallGroupInfo.fromJson(json['group']) 
          : null,
      isCaller: json['isCaller'] as bool? ?? false,
    );
  }
  
  /// 获取格式化的通话时长
  String get formattedDuration {
    if (durationSeconds <= 0) return '00:00';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 获取通话结果描述
  String get resultDescription {
    switch (result) {
      case CallResult.completed:
        return '通话时长 $formattedDuration';
      case CallResult.missed:
        return isCaller ? '对方未接听' : '未接听';
      case CallResult.rejected:
        return isCaller ? '对方已拒绝' : '已拒绝';
      case CallResult.cancelled:
        return isCaller ? '已取消' : '对方已取消';
      case CallResult.busy:
        return '对方忙线中';
      case CallResult.failed:
        return '通话失败';
    }
  }
}

/// 解析通话类型
CallType _parseCallType(dynamic value) {
  if (value == null) return CallType.voice;
  final str = value.toString().toUpperCase();
  return str == 'VIDEO' ? CallType.video : CallType.voice;
}

/// 解析房间类型
CallRoomType _parseRoomType(dynamic value) {
  if (value == null) return CallRoomType.private;
  final str = value.toString().toUpperCase();
  return str == 'GROUP' ? CallRoomType.group : CallRoomType.private;
}

/// 解析房间状态
CallRoomStatus _parseRoomStatus(dynamic value) {
  if (value == null) return CallRoomStatus.waiting;
  final str = value.toString().toUpperCase();
  switch (str) {
    case 'WAITING': return CallRoomStatus.waiting;
    case 'RINGING': return CallRoomStatus.ringing;
    case 'ACTIVE': return CallRoomStatus.active;
    case 'ENDED': return CallRoomStatus.ended;
    default: return CallRoomStatus.waiting;
  }
}

/// 解析参与者状态
CallParticipantStatus _parseParticipantStatus(dynamic value) {
  if (value == null) return CallParticipantStatus.invited;
  final str = value.toString().toUpperCase();
  switch (str) {
    case 'INVITED': return CallParticipantStatus.invited;
    case 'RINGING': return CallParticipantStatus.ringing;
    case 'JOINED': return CallParticipantStatus.joined;
    case 'LEFT': return CallParticipantStatus.left;
    case 'REJECTED': return CallParticipantStatus.rejected;
    case 'TIMEOUT': return CallParticipantStatus.timeout;
    case 'BUSY': return CallParticipantStatus.busy;
    default: return CallParticipantStatus.invited;
  }
}

/// 解析通话结果
CallResult _parseCallResult(dynamic value) {
  if (value == null) return CallResult.completed;
  final str = value.toString().toUpperCase();
  switch (str) {
    case 'COMPLETED': return CallResult.completed;
    case 'MISSED': return CallResult.missed;
    case 'REJECTED': return CallResult.rejected;
    case 'CANCELLED': return CallResult.cancelled;
    case 'BUSY': return CallResult.busy;
    case 'FAILED': return CallResult.failed;
    default: return CallResult.completed;
  }
}
