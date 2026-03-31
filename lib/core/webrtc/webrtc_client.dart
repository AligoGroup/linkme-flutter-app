import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../network/websocket_manager.dart';

/// core/webrtc/webrtc_client.dart | WebRTCClient | WebRTC客户端
/// 作用：封装WebRTC连接管理，处理音视频流
/// 包括：Peer连接、媒体流管理、ICE候选处理、信令交换、权限请求

class WebRTCClient {
  /// Peer连接
  RTCPeerConnection? _peerConnection;
  
  /// 本地媒体流
  MediaStream? _localStream;
  
  /// 远程媒体流
  MediaStream? _remoteStream;
  
  /// WebSocket管理器
  final WebSocketManager _wsManager = WebSocketManager();
  
  /// 房间UUID
  String? _roomUuid;
  
  /// 对方用户ID
  int? _targetUserId;
  
  /// 是否为发起者
  bool _isInitiator = false;
  
  /// 本地视频渲染器
  RTCVideoRenderer? localRenderer;
  
  /// 远程视频渲染器
  RTCVideoRenderer? remoteRenderer;
  
  /// 远程流回调
  Function(MediaStream)? onRemoteStream;
  
  /// ICE连接状态回调
  Function(RTCIceConnectionState)? onIceConnectionStateChanged;
  
  /// WebSocket消息订阅
  StreamSubscription? _wsSubscription;
  
  /// 待处理的ICE候选队列（在设置远程描述前收到的候选）
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  
  /// 是否已设置远程描述
  bool _remoteDescriptionSet = false;

  /// core/webrtc/webrtc_client.dart | initialize | 初始化
  /// 作用：初始化WebRTC客户端
  Future<void> initialize() async {
    if (kDebugMode) {
      print('[WebRTC] 初始化客户端');
    }
    
    // 初始化渲染器
    localRenderer = RTCVideoRenderer();
    remoteRenderer = RTCVideoRenderer();
    
    await localRenderer!.initialize();
    await remoteRenderer!.initialize();
    
    // 订阅WebSocket信令消息
    _wsSubscription = _wsManager.messageStream.listen(_handleSignalingMessage);
  }

  /// core/webrtc/webrtc_client.dart | startCall | 发起通话
  /// 作用：创建本地媒体流并建立Peer连接
  /// @param roomUuid 房间UUID
  /// @param targetUserId 对方用户ID
  /// @param isVideo 是否为视频通话
  Future<void> startCall({
    required String roomUuid,
    required int targetUserId,
    required bool isVideo,
  }) async {
    _roomUuid = roomUuid;
    _targetUserId = targetUserId;
    _isInitiator = true;
    
    if (kDebugMode) {
      print('[WebRTC] 发起通话: roomUuid=$roomUuid, targetUserId=$targetUserId, isVideo=$isVideo');
    }
    
    // 创建本地媒体流
    await _createLocalStream(isVideo);
    
    // 创建Peer连接
    await _createPeerConnection();
    
    // 添加本地流到连接
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
    
    // 创建Offer
    await _createOffer();
  }

  /// core/webrtc/webrtc_client.dart | answerCall | 接听通话
  /// 作用：接听来电，创建本地媒体流并建立Peer连接
  /// @param roomUuid 房间UUID
  /// @param targetUserId 对方用户ID
  /// @param isVideo 是否为视频通话
  Future<void> answerCall({
    required String roomUuid,
    required int targetUserId,
    required bool isVideo,
  }) async {
    _roomUuid = roomUuid;
    _targetUserId = targetUserId;
    _isInitiator = false;
    
    if (kDebugMode) {
      print('[WebRTC] 接听通话: roomUuid=$roomUuid, targetUserId=$targetUserId, isVideo=$isVideo');
    }
    
    // 创建本地媒体流
    await _createLocalStream(isVideo);
    
    // 创建Peer连接
    await _createPeerConnection();
    
    // 添加本地流到连接
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
  }

  /// core/webrtc/webrtc_client.dart | _createLocalStream | 创建本地媒体流
  /// 作用：获取本地摄像头和麦克风
  /// @param isVideo 是否包含视频
  Future<void> _createLocalStream(bool isVideo) async {
    try {
      // 仅在Android平台请求权限，iOS由WebRTC的getUserMedia自动处理
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _requestPermissions(isVideo);
      }
      
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? {
                'width': 2560,
                'height': 1440,
                'frameRate': 30,
              }
            : false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (localRenderer != null) {
        localRenderer!.srcObject = _localStream;
      }
      
      if (kDebugMode) {
        print('[WebRTC] 本地媒体流创建成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 创建本地媒体流失败: $e');
      }
      rethrow;
    }
  }

  /// core/webrtc/webrtc_client.dart | _requestPermissions | 请求权限
  /// 作用：请求摄像头和麦克风权限
  /// @param needVideo 是否需要摄像头权限
  Future<void> _requestPermissions(bool needVideo) async {
    try {
      debugPrint('[WebRTC] 开始请求权限');
      
      // 请求麦克风权限
      debugPrint('[WebRTC] 请求麦克风权限...');
      final micStatus = await Permission.microphone.request();
      debugPrint('[WebRTC] 麦克风权限状态: $micStatus');
      
      if (!micStatus.isGranted) {
        throw Exception('麦克风权限被拒绝: $micStatus');
      }
      
      // 如果需要视频，请求摄像头权限
      if (needVideo) {
        debugPrint('[WebRTC] 请求摄像头权限...');
        final cameraStatus = await Permission.camera.request();
        debugPrint('[WebRTC] 摄像头权限状态: $cameraStatus');
        
        if (!cameraStatus.isGranted) {
          throw Exception('摄像头权限被拒绝: $cameraStatus');
        }
      }
      
      debugPrint('[WebRTC] 权限请求成功');
    } catch (e) {
      debugPrint('[WebRTC] 权限请求失败: $e');
      rethrow;
    }
  }

  /// core/webrtc/webrtc_client.dart | _createPeerConnection | 创建Peer连接
  /// 作用：创建RTCPeerConnection并设置回调
  Future<void> _createPeerConnection() async {
    try {
      // STUN/TURN服务器配置
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };
      
      _peerConnection = await createPeerConnection(configuration);
      
      // 监听ICE候选
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (kDebugMode) {
          print('[WebRTC] 生成ICE候选');
        }
        _sendIceCandidate(candidate);
      };
      
      // 监听ICE连接状态
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (kDebugMode) {
          print('[WebRTC] ICE连接状态: $state');
        }
        if (onIceConnectionStateChanged != null) {
          onIceConnectionStateChanged!(state);
        }
      };
      
      // 监听远程流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (kDebugMode) {
          print('[WebRTC] 收到远程轨道');
        }
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (remoteRenderer != null) {
            remoteRenderer!.srcObject = _remoteStream;
          }
          if (onRemoteStream != null) {
            onRemoteStream!(_remoteStream!);
          }
        }
      };
      
      if (kDebugMode) {
        print('[WebRTC] Peer连接创建成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 创建Peer连接失败: $e');
      }
      rethrow;
    }
  }

  /// core/webrtc/webrtc_client.dart | _createOffer | 创建Offer
  /// 作用：发起者创建SDP Offer并发送给对方
  Future<void> _createOffer() async {
    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(offer);
      
      // 通过WebSocket发送Offer
      _wsManager.sendMessage({
        'type': 'CALL_OFFER',
        'roomUuid': _roomUuid,
        'targetUserId': _targetUserId,
        'sdp': offer.sdp,
      });
      
      if (kDebugMode) {
        print('[WebRTC] Offer已发送');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 创建Offer失败: $e');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | _createAnswer | 创建Answer
  /// 作用：接听者创建SDP Answer并发送给对方
  Future<void> _createAnswer() async {
    try {
      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      
      await _peerConnection!.setLocalDescription(answer);
      
      // 通过WebSocket发送Answer
      _wsManager.sendMessage({
        'type': 'CALL_ANSWER',
        'roomUuid': _roomUuid,
        'targetUserId': _targetUserId,
        'sdp': answer.sdp,
      });
      
      if (kDebugMode) {
        print('[WebRTC] Answer已发送');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 创建Answer失败: $e');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | _sendIceCandidate | 发送ICE候选
  /// 作用：通过WebSocket发送ICE候选给对方
  /// @param candidate ICE候选
  void _sendIceCandidate(RTCIceCandidate candidate) {
    _wsManager.sendMessage({
      'type': 'CALL_ICE_CANDIDATE',
      'roomUuid': _roomUuid,
      'targetUserId': _targetUserId,
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  /// core/webrtc/webrtc_client.dart | _handleSignalingMessage | 处理信令消息
  /// 作用：处理WebSocket收到的WebRTC信令消息
  /// @param message 信令消息
  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    
    // 只处理当前房间的消息
    final msgRoomUuid = message['roomUuid'] as String?;
    if (msgRoomUuid != _roomUuid) return;
    
    switch (type) {
      case 'CALL_OFFER':
        _handleOffer(message);
        break;
      case 'CALL_ANSWER':
        _handleAnswer(message);
        break;
      case 'CALL_ICE_CANDIDATE':
        _handleIceCandidate(message);
        break;
    }
  }

  /// core/webrtc/webrtc_client.dart | _handleOffer | 处理Offer
  /// 作用：接收者收到Offer，设置远程描述并创建Answer
  /// @param message Offer消息
  Future<void> _handleOffer(Map<String, dynamic> message) async {
    try {
      final sdp = message['sdp'] as String?;
      if (sdp == null) return;
      
      if (kDebugMode) {
        print('[WebRTC] 收到Offer');
      }
      
      RTCSessionDescription description = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(description);
      _remoteDescriptionSet = true;
      
      // 处理待处理的ICE候选
      await _processPendingIceCandidates();
      
      // 创建Answer
      await _createAnswer();
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 处理Offer失败: $e');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | _handleAnswer | 处理Answer
  /// 作用：发起者收到Answer，设置远程描述
  /// @param message Answer消息
  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    try {
      final sdp = message['sdp'] as String?;
      if (sdp == null) return;
      
      if (kDebugMode) {
        print('[WebRTC] 收到Answer');
      }
      
      RTCSessionDescription description = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(description);
      _remoteDescriptionSet = true;
      
      // 处理待处理的ICE候选
      await _processPendingIceCandidates();
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 处理Answer失败: $e');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | _handleIceCandidate | 处理ICE候选
  /// 作用：收到对方的ICE候选，添加到连接
  /// @param message ICE候选消息
  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      final candidateStr = message['candidate'] as String?;
      final sdpMid = message['sdpMid'] as String?;
      final sdpMLineIndex = message['sdpMLineIndex'] as int?;
      
      if (candidateStr == null) return;
      
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateStr,
        sdpMid ?? '',
        sdpMLineIndex ?? 0,
      );
      
      // 如果远程描述还未设置，将候选加入队列
      if (!_remoteDescriptionSet) {
        _pendingIceCandidates.add(candidate);
        if (kDebugMode) {
          print('[WebRTC] ICE候选加入待处理队列');
        }
        return;
      }
      
      await _peerConnection!.addCandidate(candidate);
      
      if (kDebugMode) {
        print('[WebRTC] ICE候选已添加');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[WebRTC] 处理ICE候选失败: $e');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | _processPendingIceCandidates | 处理待处理的ICE候选
  /// 作用：在设置远程描述后，处理之前收到的ICE候选
  Future<void> _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;
    
    if (kDebugMode) {
      print('[WebRTC] 处理 ${_pendingIceCandidates.length} 个待处理的ICE候选');
    }
    
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        if (kDebugMode) {
          print('[WebRTC] 添加待处理ICE候选失败: $e');
        }
      }
    }
    
    _pendingIceCandidates.clear();
  }

  /// core/webrtc/webrtc_client.dart | toggleAudio | 切换音频
  /// 作用：开启/关闭麦克风
  void toggleAudio(bool enabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
      if (kDebugMode) {
        print('[WebRTC] 音频已${enabled ? "开启" : "关闭"}');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | toggleVideo | 切换视频
  /// 作用：开启/关闭摄像头
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
      if (kDebugMode) {
        print('[WebRTC] 视频已${enabled ? "开启" : "关闭"}');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | switchCamera | 切换摄像头
  /// 作用：前后摄像头切换
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      if (kDebugMode) {
        print('[WebRTC] 摄像头已切换');
      }
    }
  }

  /// core/webrtc/webrtc_client.dart | close | 关闭连接
  /// 作用：清理资源，关闭所有连接
  Future<void> close() async {
    if (kDebugMode) {
      print('[WebRTC] 关闭连接');
    }
    
    _wsSubscription?.cancel();
    _wsSubscription = null;
    
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _remoteStream = null;
    
    await _peerConnection?.close();
    _peerConnection = null;
    
    await localRenderer?.dispose();
    await remoteRenderer?.dispose();
    
    _pendingIceCandidates.clear();
    _remoteDescriptionSet = false;
  }

  /// core/webrtc/webrtc_client.dart | dispose | 销毁
  /// 作用：释放所有资源
  Future<void> dispose() async {
    await close();
  }
}
