import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/call_session.dart';
import '../models/message.dart';
import '../services/call_service.dart';
import '../../core/network/websocket_manager.dart';
import '../../core/webrtc/webrtc_client.dart';
import '../../core/native/native_codec_channel.dart';
import 'chat_provider.dart';

/// shared/providers/call_provider.dart | CallProvider | 通话状态管理
/// 作用：管理音视频通话的全局状态
/// 包括：当前通话、来电处理、参与者管理、WebSocket信令监听、WebRTC连接管理

class CallProvider extends ChangeNotifier {
  final CallService _callService = CallService();
  final WebSocketManager _wsManager = WebSocketManager();
  final NativeCodecChannel _nativeCodec = NativeCodecChannel.instance;
  
  /// ChatProvider 引用，用于直接插入通话消息
  ChatProvider? _chatProvider;
  
  /// 设置 ChatProvider 引用
  void setChatProvider(ChatProvider provider) {
    _chatProvider = provider;
  }
  
  /// WebRTC客户端
  WebRTCClient? _webrtcClient;
  WebRTCClient? get webrtcClient => _webrtcClient;
  
  /// 当前通话房间
  CallRoom? _currentRoom;
  CallRoom? get currentRoom => _currentRoom;
  
  /// 是否正在通话中
  bool get isInCall => _currentRoom != null && 
      _currentRoom!.status != CallRoomStatus.ended;
  
  /// 来电信息（用于显示来电界面）
  IncomingCallInfo? _incomingCall;
  IncomingCallInfo? get incomingCall => _incomingCall;
  
  /// 是否有来电
  bool get hasIncomingCall => _incomingCall != null;
  
  /// 本地媒体状态
  bool _localAudioEnabled = true;
  bool _localVideoEnabled = false;
  bool _localScreenSharing = false;
  
  bool get localAudioEnabled => _localAudioEnabled;
  bool get localVideoEnabled => _localVideoEnabled;
  bool get localScreenSharing => _localScreenSharing;
  
  /// 通话计时器
  Timer? _callTimer;
  int _callDurationSeconds = 0;
  int get callDurationSeconds => _callDurationSeconds;
  
  /// 当前通话的被叫方ID（用于取消通话时插入消息）
  int? _currentCalleeId;
  /// 当前通话的被叫方信息
  CallUserInfo? _currentCalleeInfo;
  /// 当前通话类型（用于 initiateCall 失败时仍能插入消息）
  CallType? _pendingCallType;
  /// 当前用户ID（用于 initiateCall 失败时作为 senderId）
  int? _currentUserId;
  /// 当前群组ID（用于群聊）
  String? _currentGroupId;
  
  /// 设置通话上下文（在 initiateCall 之前调用）
  void setCallContext(int? calleeId, String? groupId, CallType callType, int currentUserId) {
    _currentCalleeId = calleeId;
    _currentGroupId = groupId;
    _pendingCallType = callType;
    _currentUserId = currentUserId;
  }
  
  /// 通话记录缓存
  List<CallRecord> _callRecords = [];
  List<CallRecord> get callRecords => _callRecords;
  
  /// WebSocket消息订阅
  StreamSubscription? _wsSubscription;
  
  /// 来电回调（用于触发来电界面）
  Function(IncomingCallInfo)? onIncomingCall;
  
  /// 通话结束回调
  Function(CallResult)? onCallEnded;
  
  /// shared/providers/call_provider.dart | onCallEndedNeedRefreshChat | 通话结束需要刷新聊天回调
  /// 作用：通话结束后，通知外部刷新聊天消息列表
  /// 参数：conversationId(会话ID), isGroup(是否群聊), result(通话结果), duration(时长秒), callType(类型)
  Function(String conversationId, bool isGroup, CallResult result, int duration, CallType callType)? onCallEndedNeedRefreshChat;

  /// shared/providers/call_provider.dart | _insertCallMessage | 插入通话消息
  /// 作用：直接通过 ChatProvider 插入通话消息，确保立即可见
  void _insertCallMessage({
    required String conversationId,
    required CallResult result,
    required int duration,
    required CallType callType,
    required int senderId,
    String? senderName,
    String? senderAvatar,
    int? receiverId,
  }) {
    if (_chatProvider == null) {
      if (kDebugMode) {
        print('[通话Provider] ChatProvider 未设置，无法插入通话消息');
      }
      return;
    }
    
    final now = DateTime.now();
    // 映射 CallResult 到字符串
    String statusStr = 'COMPLETED';
    switch (result) {
      case CallResult.completed:
        statusStr = 'COMPLETED';
        break;
      case CallResult.missed:
        statusStr = 'MISSED';
        break;
      case CallResult.cancelled:
        statusStr = 'CANCELLED';
        break;
      case CallResult.rejected:
        statusStr = 'REJECTED';
        break;
      case CallResult.busy:
        statusStr = 'REJECTED';
        break;
      case CallResult.failed:
        statusStr = 'FAILED';
        break;
    }
    
    final message = Message(
      id: -now.millisecondsSinceEpoch, // 临时负ID
      senderId: senderId,
      senderName: senderName ?? '用户',
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      content: '[通话]',
      type: MessageType.call,
      createdAt: now,
      isRead: true,
      callType: callType == CallType.video ? 'VIDEO' : 'VOICE',
      callResult: statusStr,
      callDurationSeconds: duration,
    );
    
    _chatProvider!.upsertLocalMessage(conversationId, message);
    
    if (kDebugMode) {
      print('[通话Provider] 已插入通话消息: conversationId=$conversationId, result=$statusStr, duration=$duration');
    }
  }

  /// shared/providers/call_provider.dart | init | 初始化
  /// 作用：初始化通话Provider，订阅WebSocket消息
  void init() {
    _wsSubscription?.cancel();
    _wsSubscription = _wsManager.messageStream.listen(_handleWebSocketMessage);
    
    // 初始化Native编解码器
    _initNativeCodec();
    
    if (kDebugMode) {
      print('[通话Provider] 已初始化，开始监听WebSocket消息');
    }
  }
  
  /// shared/providers/call_provider.dart | _initNativeCodec | 初始化Native编解码器
  /// 作用：初始化C++ Native层编解码器
  Future<void> _initNativeCodec() async {
    try {
      final success = await _nativeCodec.initialize();
      if (success) {
        final hwSupported = await _nativeCodec.isHardwareSupported();
        if (kDebugMode) {
          print('[通话Provider] Native编解码器初始化成功');
          print('[通话Provider] 硬件加速: ${hwSupported ? "支持" : "不支持"}');
        }
        
        // 预热编解码器
        await _nativeCodec.warmup();
      } else {
        if (kDebugMode) {
          print('[通话Provider] Native编解码器初始化失败');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[通话Provider] Native编解码器初始化异常: $e');
      }
    }
  }
  
  /// shared/providers/call_provider.dart | dispose | 销毁
  /// 作用：清理资源
  @override
  void dispose() {
    _wsSubscription?.cancel();
    _callTimer?.cancel();
    _webrtcClient?.dispose();
    super.dispose();
  }
  
  /// shared/providers/call_provider.dart | _handleWebSocketMessage | 处理WebSocket消息
  /// 作用：处理通话相关的WebSocket信令消息
  /// @param message WebSocket消息
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    
    switch (type) {
      case 'CALL_INCOMING':
        _handleIncomingCall(message);
        break;
      case 'CALL_PARTICIPANT_JOINED':
        _handleParticipantJoined(message);
        break;
      case 'CALL_PARTICIPANT_LEFT':
        _handleParticipantLeft(message);
        break;
      case 'CALL_MEDIA_STATE_CHANGED':
        _handleMediaStateChanged(message);
        break;
      case 'CALL_ENDED':
        _handleCallEnded(message);
        break;
      case 'CALL_OFFER':
      case 'CALL_ANSWER':
      case 'CALL_ICE_CANDIDATE':
        // WebRTC信令消息，由WebRTC层处理
        _handleWebRTCSignaling(message);
        break;
    }
  }
  
  /// shared/providers/call_provider.dart | _handleIncomingCall | 处理来电
  /// 作用：收到来电通知，显示来电界面
  /// @param message 来电消息
  void _handleIncomingCall(Map<String, dynamic> message) {
    final roomUuid = message['roomUuid'] as String?;
    final callTypeStr = message['callType'] as String?;
    final roomTypeStr = message['roomType'] as String?;
    
    if (roomUuid == null) return;
    
    // 如果已在通话中，忽略来电
    if (isInCall) {
      if (kDebugMode) {
        print('[通话Provider] 已在通话中，忽略来电');
      }
      return;
    }
    
    final callType = callTypeStr?.toUpperCase() == 'VIDEO' 
        ? CallType.video : CallType.voice;
    final roomType = roomTypeStr?.toUpperCase() == 'GROUP' 
        ? CallRoomType.group : CallRoomType.private;
    
    CallUserInfo? caller;
    CallGroupInfo? group;
    
    if (message['caller'] is Map<String, dynamic>) {
      caller = CallUserInfo.fromJson(message['caller']);
    }
    if (message['group'] is Map<String, dynamic>) {
      group = CallGroupInfo.fromJson(message['group']);
    }
    
    _incomingCall = IncomingCallInfo(
      roomUuid: roomUuid,
      callType: callType,
      roomType: roomType,
      caller: caller,
      group: group,
    );
    
    notifyListeners();
    
    // 触发来电回调
    if (onIncomingCall != null) {
      onIncomingCall!(_incomingCall!);
    }
    
    if (kDebugMode) {
      print('[通话Provider] 收到来电: $roomUuid, 类型: $callType');
    }
  }

  /// shared/providers/call_provider.dart | _handleParticipantJoined | 处理参与者加入
  /// 作用：更新房间参与者列表
  /// @param message 参与者加入消息
  void _handleParticipantJoined(Map<String, dynamic> message) {
    if (_currentRoom == null) return;
    
    final roomUuid = message['roomUuid'] as String?;
    if (roomUuid != _currentRoom!.roomUuid) return;
    
    // 刷新房间信息
    _refreshRoomInfo();
    
    if (kDebugMode) {
      print('[通话Provider] 参与者加入: ${message['user']}');
    }
  }
  
  /// shared/providers/call_provider.dart | _handleParticipantLeft | 处理参与者离开
  /// 作用：更新房间参与者列表
  /// @param message 参与者离开消息
  void _handleParticipantLeft(Map<String, dynamic> message) {
    if (_currentRoom == null) return;
    
    final roomUuid = message['roomUuid'] as String?;
    if (roomUuid != _currentRoom!.roomUuid) return;
    
    // 刷新房间信息
    _refreshRoomInfo();
    
    if (kDebugMode) {
      print('[通话Provider] 参与者离开: ${message['userId']}');
    }
  }
  
  /// shared/providers/call_provider.dart | _handleMediaStateChanged | 处理媒体状态变化
  /// 作用：更新参与者的媒体状态
  /// @param message 媒体状态变化消息
  void _handleMediaStateChanged(Map<String, dynamic> message) {
    if (_currentRoom == null) return;
    
    final roomUuid = message['roomUuid'] as String?;
    if (roomUuid != _currentRoom!.roomUuid) return;
    
    // 刷新房间信息
    _refreshRoomInfo();
  }
  
  /// shared/providers/call_provider.dart | _handleCallEnded | 处理通话结束
  /// 作用：清理通话状态，并通知外部刷新聊天消息列表以显示通话卡片
  /// @param message 通话结束消息
  void _handleCallEnded(Map<String, dynamic> message) {
    final roomUuid = message['roomUuid'] as String?;
    final resultStr = message['result'] as String?;
    
    // 检查是否为当前通话或来电
    if (_currentRoom?.roomUuid == roomUuid || _incomingCall?.roomUuid == roomUuid) {
      final result = _parseCallResult(resultStr);
      
      // 保存当前房间信息，用于刷新聊天消息
      final currentRoomType = _currentRoom?.roomType;
      final currentGroupId = _currentRoom?.group?.id;
      final currentCallerId = _currentRoom?.caller?.id;
      
      // shared/providers/call_provider.dart | _handleCallEnded | 获取对方用户ID
      // 作用：从参与者列表中找到对方的ID（排除发起者）
      int? currentCalleeId;
      if (_currentRoom?.participants != null && _currentRoom!.participants.isNotEmpty) {
        // 找到第一个不是发起者的参与者
        final otherParticipant = _currentRoom!.participants.firstWhere(
          (p) => p.userId != currentCallerId,
          orElse: () => _currentRoom!.participants.first,
        );
        currentCalleeId = otherParticipant.userId;
      }
      
      final currentUserId = currentCallerId; // 当前用户是发起者
      
      // Capture data before clearing state
      final duration = _callDurationSeconds;
      final type = _currentRoom?.callType ?? CallType.voice;

      _stopCallTimer();
      _cleanupWebRTC();
      _currentRoom = null;
      _incomingCall = null;
      _callDurationSeconds = 0;
      
      notifyListeners();
      
      // shared/providers/call_provider.dart | _handleCallEnded | 通知外部刷新聊天消息
      // 作用：通话结束后，立即通知 UI 进行本地模拟插入，并延迟 1秒 拉取后端数据
      if (onCallEndedNeedRefreshChat != null && currentRoomType != null) {
        // 确定会话ID (使用捕获的 locals)
        String? conversationId;
        bool isGroup = false;
        
        if (currentRoomType == CallRoomType.group && currentGroupId != null) {
          conversationId = currentGroupId.toString();
          isGroup = true;
        } else if (currentRoomType == CallRoomType.private) {
          // 私聊：会话ID是对方的ID
          if (currentUserId == currentCallerId) {
            conversationId = currentCalleeId?.toString();
          } else {
            conversationId = currentCallerId?.toString();
          }
        }
        
        if (conversationId != null) {
          // 立即触发 Optimistic UI 更新
          onCallEndedNeedRefreshChat!(conversationId, isGroup, result, duration, type);
          
          // 插入本地消息
          _insertCallMessage(
              conversationId: conversationId,
              result: result,
              duration: duration,
              callType: type,
              senderId: currentCallerId ?? 0,
              senderName: _currentRoom?.caller?.nickname ?? _currentRoom?.caller?.username,
              senderAvatar: _currentRoom?.caller?.avatar,
          );

          if (kDebugMode) {
            print('[通话Provider] 已插入通话结束消息: conversationId=$conversationId, isGroup=$isGroup, duration=$duration');
          }
        }
      }
      
      // 触发通话结束回调
      if (onCallEnded != null) {
        onCallEnded!(result);
      }
      
      if (kDebugMode) {
        print('[通话Provider] 通话结束: $roomUuid, 结果: $result');
      }
    }
  }
  
  /// shared/providers/call_provider.dart | _handleWebRTCSignaling | 处理WebRTC信令
  /// 作用：转发WebRTC信令消息（由WebRTC层处理）
  /// @param message 信令消息
  void _handleWebRTCSignaling(Map<String, dynamic> message) {
    // WebRTC信令消息由WebRTC客户端层处理
    // 这里可以添加信令消息的回调
    if (kDebugMode) {
      print('[通话Provider] 收到WebRTC信令: ${message['type']}');
    }
  }

  /// shared/providers/call_provider.dart | initiateCall | 发起通话
  /// 作用：发起语音或视频通话
  /// @param callType 通话类型
  /// @param roomType 房间类型
  /// @param calleeId 接收者ID（私聊）
  /// @param groupId 群聊ID（群聊）
  Future<CallRoom?> initiateCall({
    required CallType callType,
    required CallRoomType roomType,
    int? calleeId,
    int? groupId,
  }) async {
    if (isInCall) {
      if (kDebugMode) {
        print('[通话Provider] 已在通话中，无法发起新通话');
      }
      return null;
    }
    
    final room = await _callService.initiateCall(
      callType: callType,
      roomType: roomType,
      calleeId: calleeId,
      groupId: groupId,
    );
    
    if (room != null) {
      _currentRoom = room;
      _currentCalleeId = calleeId; // 保存被叫方ID
      _localVideoEnabled = callType == CallType.video;
      _localAudioEnabled = true;
      notifyListeners();
      
      // 初始化WebRTC客户端
      await _initWebRTC(room, calleeId ?? 0, callType == CallType.video, true);
      
      if (kDebugMode) {
        print('[通话Provider] 发起通话成功: ${room.roomUuid}');
      }
    }
    
    return room;
  }
  
  /// shared/providers/call_provider.dart | answerCall | 接听通话
  /// 作用：接听来电
  /// @param roomUuid 房间UUID（可选，默认使用当前来电）
  Future<CallRoom?> answerCall([String? roomUuid]) async {
    final uuid = roomUuid ?? _incomingCall?.roomUuid;
    if (uuid == null) {
      if (kDebugMode) {
        print('[通话Provider] 无来电可接听');
      }
      return null;
    }
    
    final room = await _callService.answerCall(uuid);
    
    if (room != null) {
      _currentRoom = room;
      _incomingCall = null;
      _localVideoEnabled = room.callType == CallType.video;
      _localAudioEnabled = true;
      _startCallTimer();
      notifyListeners();
      
      // 初始化WebRTC客户端（接听方）
      final callerId = room.caller?.id ?? 0;
      await _initWebRTC(room, callerId, room.callType == CallType.video, false);
      
      if (kDebugMode) {
        print('[通话Provider] 接听通话成功: ${room.roomUuid}');
      }
    }
    
    return room;
  }
  
  /// shared/providers/call_provider.dart | rejectCall | 拒绝通话
  /// 作用：拒绝来电
  /// @param roomUuid 房间UUID（可选，默认使用当前来电）
  Future<bool> rejectCall([String? roomUuid]) async {
    final uuid = roomUuid ?? _incomingCall?.roomUuid;
    if (uuid == null) return false;
    
    final success = await _callService.rejectCall(uuid);
    
    if (success) { // 拒绝通话，插入消息
      if (_incomingCall != null) {
         try {
           final callerId = _incomingCall!.caller?.id;
           if (callerId != null) {
             _insertCallMessage(
               conversationId: callerId.toString(),
               result: CallResult.rejected,
               duration: 0,
               callType: _incomingCall!.callType,
               senderId: callerId,
               senderName: _incomingCall!.caller?.nickname ?? _incomingCall!.caller?.username,
               senderAvatar: _incomingCall!.caller?.avatar,
             );
           }
         } catch (_) {}
      }

      _incomingCall = null;
      notifyListeners();
      
      if (kDebugMode) {
        print('[通话Provider] 拒绝通话成功');
      }
    }
    
    return success;
  }

  /// shared/providers/call_provider.dart | cancelCall | 取消通话
  /// 作用：发起者取消呼叫
  Future<bool> cancelCall() async {
    // 即使 _currentRoom 为 null，也尝试插入消息（针对 initiateCall 失败的情况）
    final bool hasRoom = _currentRoom != null;
    bool success = true;
    
    if (hasRoom) {
      success = await _callService.cancelCall(_currentRoom!.roomUuid);
    }
    
    if (success) {
      // 取消通话，插入消息
      try {
        String? convId;
        int? receiverId;
        CallType callTypeToUse = _currentRoom?.callType ?? _pendingCallType ?? CallType.voice;
        int senderId = _currentRoom?.caller?.id ?? _currentUserId ?? 0;
        String? senderName = _currentRoom?.caller?.nickname ?? _currentRoom?.caller?.username;
        String? senderAvatar = _currentRoom?.caller?.avatar;
        
        final isGroup = (_currentRoom?.roomType == CallRoomType.group) || (_currentGroupId != null);
        if (isGroup) {
          convId = _currentRoom?.group?.id.toString() ?? _currentGroupId;
        } else {
          // 优先使用保存的 calleeId
          if (_currentCalleeId != null) {
            convId = _currentCalleeId.toString();
            receiverId = _currentCalleeId;
          } else if (_currentRoom != null) {
            final me = _currentRoom!.caller?.id;
            final participants = _currentRoom!.participants;
            if (participants.isNotEmpty) {
              final other = participants.firstWhere(
                  (p) => p.userId != me, 
                  orElse: () => participants.first
              ).userId;
              convId = other.toString();
              receiverId = other;
            }
          }
        }
        
        if (convId != null) {
          _insertCallMessage(
            conversationId: convId,
            result: CallResult.cancelled,
            duration: _callDurationSeconds,
            callType: callTypeToUse,
            senderId: senderId,
            senderName: senderName,
            senderAvatar: senderAvatar,
            receiverId: receiverId,
          );
        } else {
          if (kDebugMode) {
            print('[通话Provider] 无法插入通话消息: convId 为 null, calleeId=$_currentCalleeId');
          }
        }
      } catch (e) {
         if (kDebugMode) print('Cancel refresh error: $e');
      }

      _stopCallTimer();
      await _cleanupWebRTC();
      _currentRoom = null;
      _currentCalleeId = null;
      _currentGroupId = null;
      _pendingCallType = null;
      _currentUserId = null;
      _callDurationSeconds = 0;
      notifyListeners();
      
      if (kDebugMode) {
        print('[通话Provider] 取消通话成功');
      }
    }
    
    return success;
  }
  
  /// shared/providers/call_provider.dart | leaveCall | 离开通话
  /// 作用：用户主动离开通话
  Future<bool> leaveCall() async {
    if (_currentRoom == null) return false;
    
    final success = await _callService.leaveCall(_currentRoom!.roomUuid);
    
    if (success) {
      // 离开通话，插入消息
      if (_currentRoom != null) {
         try {
           final isGroup = _currentRoom!.roomType == CallRoomType.group;
           String? convId;
           int? receiverId;
           if (isGroup) {
             convId = _currentRoom!.group?.id.toString();
           } else {
             // 优先使用保存的 calleeId
             if (_currentCalleeId != null) {
               convId = _currentCalleeId.toString();
               receiverId = _currentCalleeId;
             } else {
               final me = _currentRoom!.caller?.id;
               final participants = _currentRoom!.participants;
               if (participants.isNotEmpty) {
                 final other = participants.firstWhere(
                     (p) => p.userId != me, 
                     orElse: () => participants.first
                 ).userId;
                 convId = other.toString();
                 receiverId = other;
               }
             }
           }
           if (convId != null) {
             _insertCallMessage(
               conversationId: convId,
               result: CallResult.completed,
               duration: _callDurationSeconds,
               callType: _currentRoom!.callType,
               senderId: _currentRoom!.caller?.id ?? 0,
               senderName: _currentRoom!.caller?.nickname ?? _currentRoom!.caller?.username,
               senderAvatar: _currentRoom!.caller?.avatar,
               receiverId: receiverId,
             );
           }
         } catch (_) {}
      }

      _stopCallTimer();
      await _cleanupWebRTC();
      _currentRoom = null;
      _currentCalleeId = null;
      _currentGroupId = null;
      _pendingCallType = null;
      _currentUserId = null;
      _callDurationSeconds = 0;
      notifyListeners();
      
      if (kDebugMode) {
        print('[通话Provider] 离开通话成功');
      }
    }
    
    return success;
  }
  
  /// shared/providers/call_provider.dart | endCall | 结束通话
  /// 作用：强制结束整个通话
  Future<bool> endCall() async {
    if (_currentRoom == null) return false;
    
    final success = await _callService.endCall(_currentRoom!.roomUuid);
    
    if (success) {
      // 结束通话，插入消息
      if (_currentRoom != null) {
         try {
           final isGroup = _currentRoom!.roomType == CallRoomType.group;
           String? convId;
           int? receiverId;
           if (isGroup) {
             convId = _currentRoom!.group?.id.toString();
           } else {
             // 优先使用保存的 calleeId
             if (_currentCalleeId != null) {
               convId = _currentCalleeId.toString();
               receiverId = _currentCalleeId;
             } else {
               final me = _currentRoom!.caller?.id;
               final participants = _currentRoom!.participants;
               if (participants.isNotEmpty) {
                 final other = participants.firstWhere(
                     (p) => p.userId != me, 
                     orElse: () => participants.first
                 ).userId;
                 convId = other.toString();
                 receiverId = other;
               }
             }
           }
           if (convId != null) {
             _insertCallMessage(
               conversationId: convId,
               result: CallResult.completed,
               duration: _callDurationSeconds,
               callType: _currentRoom!.callType,
               senderId: _currentRoom!.caller?.id ?? 0,
               senderName: _currentRoom!.caller?.nickname ?? _currentRoom!.caller?.username,
               senderAvatar: _currentRoom!.caller?.avatar,
               receiverId: receiverId,
             );
           }
         } catch (_) {}
      }

      _stopCallTimer();
      await _cleanupWebRTC();
      _currentRoom = null;
      _currentCalleeId = null;
      _currentGroupId = null;
      _pendingCallType = null;
      _currentUserId = null;
      _callDurationSeconds = 0;
      notifyListeners();
      
      if (kDebugMode) {
        print('[通话Provider] 结束通话成功');
      }
    }
    
    return success;
  }
  
  /// shared/providers/call_provider.dart | joinGroupCall | 加入群聊通话
  /// 作用：群成员主动加入正在进行的群聊通话
  /// @param roomUuid 房间UUID
  Future<CallRoom?> joinGroupCall(String roomUuid) async {
    if (isInCall) {
      if (kDebugMode) {
        print('[通话Provider] 已在通话中，无法加入');
      }
      return null;
    }
    
    final room = await _callService.joinGroupCall(roomUuid);
    
    if (room != null) {
      _currentRoom = room;
      _incomingCall = null;
      _localVideoEnabled = room.callType == CallType.video;
      _localAudioEnabled = true;
      _startCallTimer();
      notifyListeners();
      
      if (kDebugMode) {
        print('[通话Provider] 加入群聊通话成功: ${room.roomUuid}');
      }
    }
    
    return room;
  }

  /// shared/providers/call_provider.dart | toggleAudio | 切换音频
  /// 作用：开启/关闭麦克风
  Future<void> toggleAudio() async {
    if (_currentRoom == null) return;
    
    _localAudioEnabled = !_localAudioEnabled;
    notifyListeners();
    
    // 控制WebRTC音频
    _webrtcClient?.toggleAudio(_localAudioEnabled);
    
    await _callService.updateMediaState(
      roomUuid: _currentRoom!.roomUuid,
      audioEnabled: _localAudioEnabled,
    );
  }
  
  /// shared/providers/call_provider.dart | toggleVideo | 切换视频
  /// 作用：开启/关闭摄像头
  Future<void> toggleVideo() async {
    if (_currentRoom == null) return;
    
    _localVideoEnabled = !_localVideoEnabled;
    notifyListeners();
    
    // 控制WebRTC视频
    _webrtcClient?.toggleVideo(_localVideoEnabled);
    
    await _callService.updateMediaState(
      roomUuid: _currentRoom!.roomUuid,
      videoEnabled: _localVideoEnabled,
    );
  }
  
  /// shared/providers/call_provider.dart | switchCamera | 切换摄像头
  /// 作用：前后摄像头切换
  Future<void> switchCamera() async {
    if (_currentRoom == null || _webrtcClient == null) return;
    await _webrtcClient!.switchCamera();
  }
  
  /// shared/providers/call_provider.dart | _initWebRTC | 初始化WebRTC
  /// 作用：创建WebRTC客户端并建立连接
  /// @param room 通话房间
  /// @param targetUserId 对方用户ID
  /// @param isVideo 是否为视频通话
  /// @param isInitiator 是否为发起者
  Future<void> _initWebRTC(
    CallRoom room,
    int targetUserId,
    bool isVideo,
    bool isInitiator,
  ) async {
    try {
      // 清理旧的WebRTC客户端
      await _webrtcClient?.dispose();
      
      // 创建新的WebRTC客户端
      _webrtcClient = WebRTCClient();
      await _webrtcClient!.initialize();
      
      // 设置回调
      _webrtcClient!.onRemoteStream = (stream) {
        if (kDebugMode) {
          print('[通话Provider] 收到远程流');
        }
        notifyListeners();
      };
      
      _webrtcClient!.onIceConnectionStateChanged = (state) {
        if (kDebugMode) {
          print('[通话Provider] ICE连接状态: $state');
        }
      };
      
      // 发起或接听通话
      if (isInitiator) {
        await _webrtcClient!.startCall(
          roomUuid: room.roomUuid,
          targetUserId: targetUserId,
          isVideo: isVideo,
        );
      } else {
        await _webrtcClient!.answerCall(
          roomUuid: room.roomUuid,
          targetUserId: targetUserId,
          isVideo: isVideo,
        );
      }
      
      if (kDebugMode) {
        print('[通话Provider] WebRTC初始化成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[通话Provider] WebRTC初始化失败: $e');
      }
    }
  }
  
  /// shared/providers/call_provider.dart | toggleScreenSharing | 切换屏幕共享
  /// 作用：开启/关闭屏幕共享
  Future<void> toggleScreenSharing() async {
    if (_currentRoom == null) return;
    
    _localScreenSharing = !_localScreenSharing;
    notifyListeners();
    
    await _callService.updateMediaState(
      roomUuid: _currentRoom!.roomUuid,
      screenSharing: _localScreenSharing,
    );
  }
  
  /// shared/providers/call_provider.dart | loadCallRecords | 加载通话记录
  /// 作用：获取通话历史记录
  /// @param page 页码
  /// @param size 每页数量
  Future<void> loadCallRecords({int page = 0, int size = 20}) async {
    final records = await _callService.getCallRecords(page: page, size: size);
    
    if (page == 0) {
      _callRecords = records;
    } else {
      _callRecords.addAll(records);
    }
    
    notifyListeners();
  }
  
  /// shared/providers/call_provider.dart | _refreshRoomInfo | 刷新房间信息
  /// 作用：从服务器获取最新的房间信息
  Future<void> _refreshRoomInfo() async {
    if (_currentRoom == null) return;
    
    final room = await _callService.getRoomInfo(_currentRoom!.roomUuid);
    if (room != null) {
      _currentRoom = room;
      notifyListeners();
    }
  }
  
  /// shared/providers/call_provider.dart | _startCallTimer | 开始通话计时
  /// 作用：启动通话时长计时器
  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }
  
  /// shared/providers/call_provider.dart | _stopCallTimer | 停止通话计时
  /// 作用：停止通话时长计时器
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }
  
  /// shared/providers/call_provider.dart | _cleanupWebRTC | 清理WebRTC资源
  /// 作用：关闭WebRTC连接并释放资源
  Future<void> _cleanupWebRTC() async {
    if (_webrtcClient != null) {
      await _webrtcClient!.close();
      _webrtcClient = null;
      if (kDebugMode) {
        print('[通话Provider] WebRTC资源已清理');
      }
    }
  }
  
  /// 获取格式化的通话时长
  String get formattedDuration {
    final minutes = _callDurationSeconds ~/ 60;
    final seconds = _callDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 清除来电
  void clearIncomingCall() {
    _incomingCall = null;
    notifyListeners();
  }
}

/// 解析通话结果
CallResult _parseCallResult(String? value) {
  if (value == null) return CallResult.completed;
  switch (value.toUpperCase()) {
    case 'COMPLETED': return CallResult.completed;
    case 'MISSED': return CallResult.missed;
    case 'REJECTED': return CallResult.rejected;
    case 'CANCELLED': return CallResult.cancelled;
    case 'BUSY': return CallResult.busy;
    case 'FAILED': return CallResult.failed;
    default: return CallResult.completed;
  }
}

/// 来电信息
class IncomingCallInfo {
  final String roomUuid;
  final CallType callType;
  final CallRoomType roomType;
  final CallUserInfo? caller;
  final CallGroupInfo? group;
  
  IncomingCallInfo({
    required this.roomUuid,
    required this.callType,
    required this.roomType,
    this.caller,
    this.group,
  });
  
  /// 获取显示标题
  String get displayTitle {
    if (roomType == CallRoomType.group && group != null) {
      return group!.name ?? '群聊通话';
    } else if (caller != null) {
      return caller!.displayName;
    }
    return '来电';
  }
  
  /// 是否为视频通话
  bool get isVideo => callType == CallType.video;
}
