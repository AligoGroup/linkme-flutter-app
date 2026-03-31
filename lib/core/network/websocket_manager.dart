import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'server_health.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  WebSocketStatus _status = WebSocketStatus.disconnected;
  int _reconnectAttempts = 0;
  String? _userId;
  String? _token;

  // 事件流控制器
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WebSocketStatus> _statusController =
      StreamController<WebSocketStatus>.broadcast();

  // Getters
  WebSocketStatus get status => _status;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<WebSocketStatus> get statusStream => _statusController.stream;
  bool get isConnected => _status == WebSocketStatus.connected;

  // 连接WebSocket
  Future<void> connect(String userId, String token) async {
    // 若已连接到不同用户，需先断开再重连，确保从匿名连接切换到真实用户连接
    if (_status == WebSocketStatus.connected) {
      if (_userId != userId || _token != token) {
        disconnect();
      } else {
        return; // 已连接且目标一致，无需重复连接
      }
    }
    if (_status == WebSocketStatus.connecting) return;

    _userId = userId;
    _token = token;
    
    _updateStatus(WebSocketStatus.connecting);

    try {
      final wsUrl = '${ApiConfig.wsUrl}/$userId';
      if (kDebugMode) {
        print('🔗 正在连接WebSocket: $wsUrl');
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // 监听消息
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnect,
      );

      _updateStatus(WebSocketStatus.connected);
      // WebSocket连通，认为服务器可达
      ServerHealth().setHealthy();
      _reconnectAttempts = 0;
      
      // 启动心跳
      _startHeartbeat();
      
      if (kDebugMode) {
        print('✅ WebSocket连接成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ WebSocket连接失败: $e');
      }
      _updateStatus(WebSocketStatus.error);
      // 连接失败视为服务器不可达（或网络异常）
      ServerHealth().setError();
      _scheduleReconnect();
    }
  }

  // 断开连接
  void disconnect() {
    _stopHeartbeat();
    _stopReconnect();
    
    _subscription?.cancel();
    _subscription = null;
    
    _channel?.sink.close();
    _channel = null;
    
    _updateStatus(WebSocketStatus.disconnected);
    
    if (kDebugMode) {
      print('🔌 WebSocket已断开连接');
    }
  }

  // 发送消息
  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && isConnected) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
        
        if (kDebugMode) {
          print('📤 发送WebSocket消息: $jsonMessage');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 发送WebSocket消息失败: $e');
        }
      }
    } else {
      if (kDebugMode) {
        print('⚠️ WebSocket未连接，无法发送消息');
      }
    }
  }

  // 发送聊天消息
  void sendChatMessage({
    required String receiverId,
    required String content,
    String type = 'TEXT',
    bool isGroup = false,
    int? messageId, // 可选：携带服务端生成的消息ID，帮助接收端精确去重
    DateTime? createdAt, // 可选：携带服务端/本地时间
  }) {
    final message = {
      'type': 'CHAT_MESSAGE',
      'receiverId': receiverId,
      'content': content,
      'messageType': type,
      'isGroup': isGroup,
      'timestamp': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      if (messageId != null) 'messageId': messageId,
    };
    
    sendMessage(message);
  }

  // 处理接收到的消息
  void _onMessage(dynamic data) {
    try {
      final messageData = json.decode(data.toString());
      
      if (kDebugMode) {
        print('📥 收到WebSocket消息: $messageData');
      }

      // 处理特殊消息类型
      final messageType = messageData['type'];
      if (messageType == 'PONG') {
        // 心跳响应，不需要特殊处理
        return;
      }

      // 广播消息给监听者
      _messageController.add(messageData);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 解析WebSocket消息失败: $e');
      }
    }
  }

  // 处理WebSocket错误
  void _onError(dynamic error) {
    if (kDebugMode) {
      print('❌ WebSocket错误: $error');
    }
    
    _updateStatus(WebSocketStatus.error);
    _scheduleReconnect();
  }

  // 处理WebSocket断开
  void _onDisconnect() {
    if (kDebugMode) {
      print('🔌 WebSocket连接断开');
    }
    
    _stopHeartbeat();
    _updateStatus(WebSocketStatus.disconnected);
    // 断开连接可能由网络或后端导致，这里同样标记错误；
    // 当HTTP/WS恢复成功时会自动置为 healthy
    ServerHealth().setError();
    _scheduleReconnect();
  }

  // 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(ApiConfig.heartbeatInterval, (timer) {
      if (isConnected) {
        sendMessage({
          'type': 'PING',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  // 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= ApiConfig.maxReconnectAttempts) {
      if (kDebugMode) {
        print('⚠️ 已达到最大重连次数，停止重连');
      }
      return;
    }

    _stopReconnect();
    
    _reconnectAttempts++;
    _updateStatus(WebSocketStatus.reconnecting);
    
    if (kDebugMode) {
      print('🔄 安排WebSocket重连，第$_reconnectAttempts次尝试...');
    }

    _reconnectTimer = Timer(ApiConfig.reconnectDelay, () {
      if (_userId != null && _token != null) {
        connect(_userId!, _token!);
      }
    });
  }

  // 停止重连
  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // 更新状态
  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
      
      if (kDebugMode) {
        print('📡 WebSocket状态变化: ${_getStatusText(newStatus)}');
      }
    }
  }

  // 获取状态文本
  String _getStatusText(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.disconnected:
        return '已断开';
      case WebSocketStatus.connecting:
        return '连接中';
      case WebSocketStatus.connected:
        return '已连接';
      case WebSocketStatus.reconnecting:
        return '重连中';
      case WebSocketStatus.error:
        return '连接错误';
    }
  }

  // 销毁
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}
