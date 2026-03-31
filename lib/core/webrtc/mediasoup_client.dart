import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

/// core/webrtc/mediasoup_client.dart | MediasoupClient | mediasoup客户端
/// 作用：封装mediasoup SFU连接，处理多人音视频通话
/// 包括：Socket.IO连接、Device创建、传输管理、生产者/消费者管理

class MediasoupClient {
  /// Socket.IO客户端
  IO.Socket? _socket;
  
  /// mediasoup Device
  dynamic _device;
  
  /// 房间ID
  String? _roomId;
  
  /// 参与者ID
  String? _peerId;
  
  /// 发送传输
  RTCPeerConnection? _sendTransport;
  
  /// 接收传输
  RTCPeerConnection? _recvTransport;
  
  /// 本地媒体流
  MediaStream? _localStream;
  
  /// 生产者Map（kind -> Producer）
  final Map<String, dynamic> _producers = {};
  
  /// 消费者Map（consumerId -> Consumer）
  final Map<String, dynamic> _consumers = {};
  
  /// 远程流Map（peerId -> MediaStream）
  final Map<String, MediaStream> _remoteStreams = {};
  
  /// 本地视频渲染器
  RTCVideoRenderer? localRenderer;
  
  /// 远程流回调
  Function(String peerId, MediaStream stream)? onRemoteStream;
  
  /// 参与者加入回调
  Function(String peerId)? onPeerJoined;
  
  /// 参与者离开回调
  Function(String peerId)? onPeerLeft;
  
  /// mediasoup服务器地址
  String? _mediasoupUrl;

  /// core/webrtc/mediasoup_client.dart | initialize | 初始化
  /// 作用：初始化mediasoup客户端
  /// @param mediasoupUrl mediasoup服务器地址
  Future<void> initialize(String mediasoupUrl) async {
    _mediasoupUrl = mediasoupUrl;
    
    if (kDebugMode) {
      print('[Mediasoup] 初始化客户端: $_mediasoupUrl');
    }
    
    // 初始化本地渲染器
    localRenderer = RTCVideoRenderer();
    await localRenderer!.initialize();
  }

  /// core/webrtc/mediasoup_client.dart | joinRoom | 加入房间
  /// 作用：连接mediasoup服务器并加入房间
  /// @param roomId 房间ID
  /// @param peerId 参与者ID
  /// @param isVideo 是否为视频通话
  Future<void> joinRoom({
    required String roomId,
    required String peerId,
    required bool isVideo,
  }) async {
    _roomId = roomId;
    _peerId = peerId;
    
    if (kDebugMode) {
      print('[Mediasoup] 加入房间: roomId=$roomId, peerId=$peerId');
    }
    
    // 连接Socket.IO
    await _connectSocket();
    
    // 创建本地媒体流
    await _createLocalStream(isVideo);
    
    // 加入房间
    await _joinRoom();
    
    // 创建发送传输
    await _createSendTransport();
    
    // 开始生产媒体
    await _produce();
    
    // 创建接收传输
    await _createRecvTransport();
    
    // 获取并消费现有生产者
    await _consumeExistingProducers();
  }

  /// core/webrtc/mediasoup_client.dart | _connectSocket | 连接Socket.IO
  /// 作用：建立与mediasoup服务器的Socket.IO连接
  Future<void> _connectSocket() async {
    final completer = Completer<void>();
    
    _socket = IO.io(_mediasoupUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    _socket!.on('connect', (_) {
      if (kDebugMode) {
        print('[Mediasoup] Socket.IO已连接');
      }
      completer.complete();
    });
    
    _socket!.on('disconnect', (_) {
      if (kDebugMode) {
        print('[Mediasoup] Socket.IO已断开');
      }
    });
    
    _socket!.on('peerJoined', (data) {
      final peerId = data['peerId'] as String;
      if (kDebugMode) {
        print('[Mediasoup] 参与者加入: $peerId');
      }
      if (onPeerJoined != null) {
        onPeerJoined!(peerId);
      }
    });
    
    _socket!.on('peerLeft', (data) {
      final peerId = data['peerId'] as String;
      if (kDebugMode) {
        print('[Mediasoup] 参与者离开: $peerId');
      }
      _remoteStreams.remove(peerId);
      if (onPeerLeft != null) {
        onPeerLeft!(peerId);
      }
    });
    
    _socket!.on('newProducer', (data) async {
      final producerId = data['producerId'] as String;
      final kind = data['kind'] as String;
      if (kDebugMode) {
        print('[Mediasoup] 新生产者: $producerId ($kind)');
      }
      await _consume(producerId);
    });
    
    _socket!.on('producerClosed', (data) {
      final producerId = data['producerId'] as String;
      if (kDebugMode) {
        print('[Mediasoup] 生产者关闭: $producerId');
      }
      // 移除对应的消费者
      _consumers.removeWhere((key, value) => value['producerId'] == producerId);
    });
    
    _socket!.connect();
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | _createLocalStream | 创建本地媒体流
  /// 作用：获取本地摄像头和麦克风
  /// @param isVideo 是否包含视频
  Future<void> _createLocalStream(bool isVideo) async {
    try {
      // 请求权限
      await _requestPermissions(isVideo);
      
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? {
                'width': 1280,
                'height': 720,
                'frameRate': 30,
              }
            : false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (localRenderer != null) {
        localRenderer!.srcObject = _localStream;
      }
      
      if (kDebugMode) {
        print('[Mediasoup] 本地媒体流创建成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Mediasoup] 创建本地媒体流失败: $e');
      }
      rethrow;
    }
  }

  /// core/webrtc/mediasoup_client.dart | _requestPermissions | 请求权限
  /// 作用：请求摄像头和麦克风权限
  /// @param needVideo 是否需要摄像头权限
  Future<void> _requestPermissions(bool needVideo) async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('麦克风权限被拒绝');
      }
      
      if (needVideo) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          throw Exception('摄像头权限被拒绝');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Mediasoup] 权限请求失败: $e');
      }
      rethrow;
    }
  }

  /// core/webrtc/mediasoup_client.dart | _joinRoom | 加入房间
  /// 作用：通过Socket.IO加入房间
  Future<void> _joinRoom() async {
    final completer = Completer<void>();
    
    _socket!.emitWithAck('joinRoom', {
      'roomId': _roomId,
      'peerId': _peerId,
    }, ack: (data) {
      if (data['success'] == true) {
        if (kDebugMode) {
          print('[Mediasoup] 成功加入房间');
        }
        completer.complete();
      } else {
        completer.completeError(Exception(data['error']));
      }
    });
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | _createSendTransport | 创建发送传输
  /// 作用：创建用于发送媒体的传输
  Future<void> _createSendTransport() async {
    final completer = Completer<void>();
    
    _socket!.emitWithAck('createWebRtcTransport', {
      'roomId': _roomId,
      'peerId': _peerId,
      'direction': 'send',
    }, ack: (data) async {
      if (data['success'] != true) {
        completer.completeError(Exception(data['error']));
        return;
      }
      
      final transportOptions = data['transportOptions'];
      
      // 创建RTCPeerConnection作为发送传输
      final config = {
        'iceServers': transportOptions['iceServers'] ?? [],
        'iceTransportPolicy': 'all',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      };
      
      _sendTransport = await createPeerConnection(config);
      
      // 设置ICE候选处理
      _sendTransport!.onIceCandidate = (candidate) {
        _socket!.emit('transportConnect', {
          'roomId': _roomId,
          'peerId': _peerId,
          'transportId': transportOptions['id'],
          'dtlsParameters': {
            'role': 'client',
            'fingerprints': [],
          },
        });
      };
      
      if (kDebugMode) {
        print('[Mediasoup] 发送传输创建成功');
      }
      
      completer.complete();
    });
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | _createRecvTransport | 创建接收传输
  /// 作用：创建用于接收媒体的传输
  Future<void> _createRecvTransport() async {
    final completer = Completer<void>();
    
    _socket!.emitWithAck('createWebRtcTransport', {
      'roomId': _roomId,
      'peerId': _peerId,
      'direction': 'recv',
    }, ack: (data) async {
      if (data['success'] != true) {
        completer.completeError(Exception(data['error']));
        return;
      }
      
      final transportOptions = data['transportOptions'];
      
      // 创建RTCPeerConnection作为接收传输
      final config = {
        'iceServers': transportOptions['iceServers'] ?? [],
        'iceTransportPolicy': 'all',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      };
      
      _recvTransport = await createPeerConnection(config);
      
      // 设置远程流处理
      _recvTransport!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          final peerId = event.track.id.split('_')[0]; // 从track ID提取peerId
          
          _remoteStreams[peerId] = stream;
          
          if (onRemoteStream != null) {
            onRemoteStream!(peerId, stream);
          }
          
          if (kDebugMode) {
            print('[Mediasoup] 收到远程流: $peerId');
          }
        }
      };
      
      if (kDebugMode) {
        print('[Mediasoup] 接收传输创建成功');
      }
      
      completer.complete();
    });
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | _produce | 生产媒体
  /// 作用：开始发送本地音视频
  Future<void> _produce() async {
    if (_localStream == null || _sendTransport == null) return;
    
    for (final track in _localStream!.getTracks()) {
      // 添加轨道到发送传输
      await _sendTransport!.addTrack(track, _localStream!);
      
      // 创建Offer
      final offer = await _sendTransport!.createOffer();
      await _sendTransport!.setLocalDescription(offer);
      
      // 通知服务器开始生产
      final completer = Completer<void>();
      
      _socket!.emitWithAck('produce', {
        'roomId': _roomId,
        'peerId': _peerId,
        'kind': track.kind,
        'rtpParameters': {
          'codecs': track.kind == 'video' 
              ? [{'mimeType': 'video/H265', 'clockRate': 90000}]
              : [{'mimeType': 'audio/opus', 'clockRate': 48000}],
        },
      }, ack: (data) {
        if (data['success'] == true) {
          final producerId = data['producerId'];
          _producers[track.kind!] = {
            'id': producerId,
            'track': track,
          };
          
          if (kDebugMode) {
            print('[Mediasoup] 生产媒体成功: ${track.kind}, ID: $producerId');
          }
          
          completer.complete();
        } else {
          completer.completeError(Exception(data['error']));
        }
      });
      
      await completer.future;
    }
  }

  /// core/webrtc/mediasoup_client.dart | _consumeExistingProducers | 消费现有生产者
  /// 作用：获取并消费房间内现有的生产者
  Future<void> _consumeExistingProducers() async {
    final completer = Completer<void>();
    
    _socket!.emitWithAck('getProducers', null, ack: (data) async {
      if (data['success'] == true) {
        final producers = data['producers'] as List;
        for (final producer in producers) {
          await _consume(producer['producerId']);
        }
        completer.complete();
      } else {
        completer.completeError(Exception(data['error']));
      }
    });
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | _consume | 消费媒体
  /// 作用：开始接收其他参与者的音视频
  /// @param producerId 生产者ID
  Future<void> _consume(String producerId) async {
    if (_recvTransport == null) {
      if (kDebugMode) {
        print('[Mediasoup] 接收传输未创建');
      }
      return;
    }
    
    final completer = Completer<void>();
    
    _socket!.emitWithAck('consume', {
      'roomId': _roomId,
      'peerId': _peerId,
      'producerId': producerId,
      'rtpCapabilities': {
        'codecs': [
          {'mimeType': 'video/H265', 'clockRate': 90000},
          {'mimeType': 'audio/opus', 'clockRate': 48000},
        ],
      },
    }, ack: (data) async {
      if (data['success'] != true) {
        completer.completeError(Exception(data['error']));
        return;
      }
      
      final consumerId = data['consumerId'];
      final kind = data['kind'];
      final rtpParameters = data['rtpParameters'];
      
      // 创建Answer以接收媒体
      final answer = await _recvTransport!.createAnswer();
      await _recvTransport!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], 'offer')
      );
      await _recvTransport!.setLocalDescription(answer);
      
      // 保存消费者信息
      _consumers[consumerId] = {
        'id': consumerId,
        'producerId': producerId,
        'kind': kind,
        'rtpParameters': rtpParameters,
      };
      
      // 通知服务器消费者已就绪
      _socket!.emit('consumerResume', {
        'roomId': _roomId,
        'peerId': _peerId,
        'consumerId': consumerId,
      });
      
      if (kDebugMode) {
        print('[Mediasoup] 消费媒体成功: $kind, ID: $consumerId');
      }
      
      completer.complete();
    });
    
    return completer.future;
  }

  /// core/webrtc/mediasoup_client.dart | toggleAudio | 切换音频
  /// 作用：开启/关闭麦克风
  void toggleAudio(bool enabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  /// core/webrtc/mediasoup_client.dart | toggleVideo | 切换视频
  /// 作用：开启/关闭摄像头
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  /// core/webrtc/mediasoup_client.dart | switchCamera | 切换摄像头
  /// 作用：前后摄像头切换
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  /// core/webrtc/mediasoup_client.dart | close | 关闭连接
  /// 作用：清理资源，关闭所有连接
  Future<void> close() async {
    if (kDebugMode) {
      print('[Mediasoup] 关闭连接');
    }
    
    // 关闭本地流
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    // 关闭远程流
    for (final stream in _remoteStreams.values) {
      stream.getTracks().forEach((track) => track.stop());
      stream.dispose();
    }
    _remoteStreams.clear();
    
    // 关闭传输
    await _sendTransport?.close();
    await _recvTransport?.close();
    _sendTransport = null;
    _recvTransport = null;
    
    // 断开Socket.IO
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    
    // 清理生产者和消费者
    _producers.clear();
    _consumers.clear();
    
    // 清理渲染器
    await localRenderer?.dispose();
  }

  /// core/webrtc/mediasoup_client.dart | dispose | 销毁
  /// 作用：释放所有资源
  Future<void> dispose() async {
    await close();
  }
}
