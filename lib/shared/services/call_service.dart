import 'package:flutter/foundation.dart';
import '../models/call_session.dart';
import '../../core/network/api_client.dart';

/// shared/services/call_service.dart | CallService | 通话服务
/// 作用：处理音视频通话相关的API请求
/// API前缀：/api/call

class CallService {
  final ApiClient _apiClient = ApiClient();
  
  /// shared/services/call_service.dart | initiateCall | 发起通话
  /// 作用：创建通话房间并呼叫对方
  /// API: POST /api/call/initiate
  /// @param callType 通话类型（VOICE/VIDEO）
  /// @param roomType 房间类型（PRIVATE/GROUP）
  /// @param calleeId 接收者ID（私聊时必填）
  /// @param groupId 群聊ID（群聊时必填）
  Future<CallRoom?> initiateCall({
    required CallType callType,
    required CallRoomType roomType,
    int? calleeId,
    int? groupId,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/call/initiate',
        data: {
          'callType': callType.name.toUpperCase(),
          'roomType': roomType.name.toUpperCase(),
          if (calleeId != null) 'calleeId': calleeId,
          if (groupId != null) 'groupId': groupId,
        },
      );
      
      if (response.success && response.data != null) {
        return CallRoom.fromJson(response.data!);
      }
      
      if (kDebugMode) {
        print('[通话服务] 发起通话失败: ${response.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 发起通话异常: $e');
      }
      return null;
    }
  }

  /// shared/services/call_service.dart | answerCall | 接听通话
  /// 作用：用户接听来电
  /// API: POST /api/call/answer/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<CallRoom?> answerCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/call/answer/$roomUuid',
      );
      
      if (response.success && response.data != null) {
        return CallRoom.fromJson(response.data!);
      }
      
      if (kDebugMode) {
        print('[通话服务] 接听通话失败: ${response.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 接听通话异常: $e');
      }
      return null;
    }
  }
  
  /// shared/services/call_service.dart | rejectCall | 拒绝通话
  /// 作用：用户拒绝来电
  /// API: POST /api/call/reject/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<bool> rejectCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<void>('/call/reject/$roomUuid');
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 拒绝通话异常: $e');
      }
      return false;
    }
  }
  
  /// shared/services/call_service.dart | cancelCall | 取消通话
  /// 作用：发起者取消呼叫
  /// API: POST /api/call/cancel/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<bool> cancelCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<void>('/call/cancel/$roomUuid');
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 取消通话异常: $e');
      }
      return false;
    }
  }

  /// shared/services/call_service.dart | leaveCall | 离开通话
  /// 作用：用户主动离开通话
  /// API: POST /api/call/leave/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<bool> leaveCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<void>('/call/leave/$roomUuid');
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 离开通话异常: $e');
      }
      return false;
    }
  }
  
  /// shared/services/call_service.dart | endCall | 结束通话
  /// 作用：强制结束整个通话
  /// API: POST /api/call/end/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<bool> endCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<void>('/call/end/$roomUuid');
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 结束通话异常: $e');
      }
      return false;
    }
  }
  
  /// shared/services/call_service.dart | joinGroupCall | 加入群聊通话
  /// 作用：群成员主动加入正在进行的群聊通话
  /// API: POST /api/call/join/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<CallRoom?> joinGroupCall(String roomUuid) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/call/join/$roomUuid',
      );
      
      if (response.success && response.data != null) {
        return CallRoom.fromJson(response.data!);
      }
      
      if (kDebugMode) {
        print('[通话服务] 加入群聊通话失败: ${response.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 加入群聊通话异常: $e');
      }
      return null;
    }
  }

  /// shared/services/call_service.dart | updateMediaState | 更新媒体状态
  /// 作用：更新用户的音视频开关状态
  /// API: POST /api/call/media-state
  /// @param roomUuid 房间UUID
  /// @param audioEnabled 音频是否开启
  /// @param videoEnabled 视频是否开启
  /// @param screenSharing 是否共享屏幕
  Future<bool> updateMediaState({
    required String roomUuid,
    bool? audioEnabled,
    bool? videoEnabled,
    bool? screenSharing,
  }) async {
    try {
      final response = await _apiClient.post<void>(
        '/call/media-state',
        data: {
          'roomUuid': roomUuid,
          if (audioEnabled != null) 'audioEnabled': audioEnabled,
          if (videoEnabled != null) 'videoEnabled': videoEnabled,
          if (screenSharing != null) 'screenSharing': screenSharing,
        },
      );
      return response.success;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 更新媒体状态异常: $e');
      }
      return false;
    }
  }
  
  /// shared/services/call_service.dart | getRoomInfo | 获取房间信息
  /// 作用：获取通话房间详细信息
  /// API: GET /api/call/room/{roomUuid}
  /// @param roomUuid 房间UUID
  Future<CallRoom?> getRoomInfo(String roomUuid) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/call/room/$roomUuid',
      );
      
      if (response.success && response.data != null) {
        return CallRoom.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 获取房间信息异常: $e');
      }
      return null;
    }
  }
  
  /// shared/services/call_service.dart | getCallRecords | 获取通话记录
  /// 作用：获取用户的通话历史记录
  /// API: GET /api/call/records
  /// @param page 页码
  /// @param size 每页数量
  Future<List<CallRecord>> getCallRecords({int page = 0, int size = 20}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/call/records',
        queryParameters: {'page': page, 'size': size},
      );
      
      if (response.success && response.data != null) {
        final content = response.data!['content'] as List<dynamic>?;
        if (content != null) {
          return content
              .map((e) => CallRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 获取通话记录异常: $e');
      }
      return [];
    }
  }
  
  /// shared/services/call_service.dart | checkUserInCall | 检查用户是否在通话中
  /// 作用：判断用户当前是否正在进行通话
  /// API: GET /api/call/status
  Future<bool> checkUserInCall() async {
    try {
      final response = await _apiClient.get<bool>('/call/status');
      return response.success && response.data == true;
    } catch (e) {
      if (kDebugMode) {
        print('[通话服务] 检查通话状态异常: $e');
      }
      return false;
    }
  }
}
