import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/models/call_session.dart';
import '../../shared/providers/call_provider.dart';
import '../../shared/providers/auth_provider.dart';

/// features/call/call_screen.dart | CallScreen | 通话界面
/// 作用：音视频通话的主界面，支持私聊和群聊通话
/// 包括：通话状态显示、控制按钮、参与者列表、视频画面渲染

class CallScreen extends StatefulWidget {
  /// 房间UUID（已在通话中时传入）
  final String? roomUuid;
  
  /// 是否为来电（用于显示接听/拒绝按钮）
  final bool isIncoming;
  
  /// 通话类型
  final CallType callType;
  
  /// 房间类型
  final CallRoomType roomType;
  
  /// 对方信息（私聊时使用）
  final CallUserInfo? peerUser;
  
  /// 群聊信息（群聊时使用）
  final CallGroupInfo? groupInfo;
  
  /// 接收者ID（发起私聊通话时使用）
  final int? calleeId;
  
  /// 群聊ID（发起群聊通话时使用）
  final int? groupId;

  const CallScreen({
    super.key,
    this.roomUuid,
    this.isIncoming = false,
    required this.callType,
    required this.roomType,
    this.peerUser,
    this.groupInfo,
    this.calleeId,
    this.groupId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  /// 通话状态文本
  String _statusText = '正在连接...';
  
  /// 是否已接通
  bool _isConnected = false;
  
  /// 是否正在呼叫中（等待对方接听）
  bool _isCalling = false;
  
  /// 是否为来电等待接听
  bool _isRinging = false;
  
  /// 是否正在结束通话（防止重复Pop）
  bool _isEnding = false;
  
  /// 扬声器是否开启
  bool _speakerEnabled = false;
  
  /// 呼叫超时定时器
  Timer? _callTimeout;
  
  /// 铃声播放器
  AudioPlayer? _ringtonePlayer;
  
  /// 权限是否已授权
  bool _permissionsGranted = false;
  
  /// 动态省略号计数器（用于"等待对方接听"动画）
  int _dotCount = 0;
  
  /// 动态省略号定时器
  Timer? _dotTimer;
  
  @override
  void initState() {
    super.initState();
    // 调试日志：记录CallScreen初始化时的callType
    debugPrint('[通话界面] CallScreen初始化，callType: ${widget.callType} (${widget.callType.name})');
    debugPrint('[通话界面] 房间类型: ${widget.roomType.name}，是否来电: ${widget.isIncoming}');
    
    // 设置全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 设置屏幕方向为竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _initCall();
  }
  
  @override
  void dispose() {
    // 取消超时定时器
    _callTimeout?.cancel();
    // 取消省略号动画定时器
    _dotTimer?.cancel();
    // 停止铃声
    _stopRingtone();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 恢复屏幕方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 移除监听器
    try {
      final callProvider = context.read<CallProvider>();
      callProvider.removeListener(_onCallStateChanged);
      callProvider.onCallEnded = null;
    } catch (_) {}
    super.dispose();
  }
  
  /// features/call/call_screen.dart | _requestPermissions | 请求权限
  /// 作用：请求摄像头和麦克风权限（iOS由WebRTC自动处理）
  Future<bool> _requestPermissions() async {
    try {
      debugPrint('[通话] 权限检查开始');
      
      // 在iOS上，权限由WebRTC的getUserMedia自动触发
      // 在Android上，使用permission_handler显式请求
      if (Theme.of(context).platform == TargetPlatform.android) {
        debugPrint('[通话] Android平台，请求权限...');
        
        // 请求麦克风权限
        final micStatus = await Permission.microphone.request();
        debugPrint('[通话] 麦克风权限状态: $micStatus');
        
        if (!micStatus.isGranted) {
          if (mounted) {
            if (micStatus.isDenied) {
              _showError('需要麦克风权限才能进行通话');
            } else if (micStatus.isPermanentlyDenied) {
              _showError('麦克风权限被永久拒绝，请在设置中启用');
              openAppSettings();
            }
          }
          return false;
        }
        
        // 视频通话需要摄像头权限
        if (widget.callType == CallType.video) {
          final cameraStatus = await Permission.camera.request();
          debugPrint('[通话] 摄像头权限状态: $cameraStatus');
          
          if (!cameraStatus.isGranted) {
            if (mounted) {
              if (cameraStatus.isDenied) {
                _showError('需要摄像头权限才能进行视频通话');
              } else if (cameraStatus.isPermanentlyDenied) {
                _showError('摄像头权限被永久拒绝，请在设置中启用');
                openAppSettings();
              }
            }
            return false;
          }
        }
      } else {
        // iOS平台：权限由WebRTC的getUserMedia自动触发
        debugPrint('[通话] iOS平台，权限由WebRTC自动处理');
      }
      
      debugPrint('[通话] 权限检查完成');
      return true;
    } catch (e) {
      debugPrint('[通话] 权限检查异常: $e');
      if (mounted) {
        _showError('权限检查失败: $e');
      }
      return false;
    }
  }
  
  /// features/call/call_screen.dart | _playRingtone | 播放铃声
  /// 作用：拨打或来电时播放铃声
  Future<void> _playRingtone() async {
    try {
      _ringtonePlayer = AudioPlayer();
      // 设置循环播放
      await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      // 播放铃声资源文件
      // 注意：需要在assets/sounds/目录下放置ringtone.mp3文件
      await _ringtonePlayer!.play(
        AssetSource('sounds/ringtone.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      // 铃声播放失败时使用系统振动作为备选
      debugPrint('[通话] 铃声播放失败: $e');
      // 可以在这里添加系统振动
      HapticFeedback.vibrate();
    }
  }
  
  /// features/call/call_screen.dart | _stopRingtone | 停止铃声
  /// 作用：停止播放铃声
  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.dispose();
      _ringtonePlayer = null;
    } catch (_) {}
  }
  
  /// features/call/call_screen.dart | _initCall | 初始化通话
  /// 作用：根据是来电还是去电，初始化通话状态
  Future<void> _initCall() async {
    debugPrint('[通话界面] _initCall开始: callType=${widget.callType.name}, isIncoming=${widget.isIncoming}, roomUuid=${widget.roomUuid}');
    
    final callProvider = context.read<CallProvider>();
    
    if (widget.isIncoming) {
      // 来电：显示接听/拒绝按钮，播放铃声
      setState(() {
        _isRinging = true;
        _statusText = widget.callType == CallType.video ? '视频通话' : '语音通话';
      });
      debugPrint('[通话界面] 来电模式: 显示接听/拒绝按钮');
      // 播放来电铃声
      _playRingtone();
    } else if (widget.roomUuid != null) {
      // 已有房间：直接进入通话
      setState(() {
        _isConnected = true;
        _statusText = '通话中';
      });
      debugPrint('[通话界面] 已有房间: 直接进入通话');
    } else {
      // 发起通话：先请求权限
      debugPrint('[通话界面] 发起通话模式: 请求权限');
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _permissionsGranted = true;
      
      setState(() {
        _isCalling = true;
        _statusText = '正在呼叫...';
      });
      
      // 播放呼叫铃声
      _playRingtone();
      
      // 预设通话上下文（即使 initiateCall 失败，cancelCall 时也能插入消息）
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        callProvider.setCallContext(
          widget.calleeId,
          widget.groupId?.toString(),
          widget.callType,
          authProvider.user!.id
        );
      }
      
      final room = await callProvider.initiateCall(
        callType: widget.callType,
        roomType: widget.roomType,
        calleeId: widget.calleeId,
        groupId: widget.groupId,
      );
      
      if (room == null) {
        // 发起失败
        await _stopRingtone();
        if (mounted) {
          _showError('发起通话失败');
          Navigator.of(context).pop();
        }
        return;
      }
      
      // 等待对方接听，设置30秒超时
      setState(() {
        _statusText = '等待对方接听...';
      });
      
      _startCallTimeout();
    }
    
    // 监听通话状态变化
    callProvider.addListener(_onCallStateChanged);
    callProvider.onCallEnded = _onCallEnded;
  }
  
  /// features/call/call_screen.dart | _startCallTimeout | 启动呼叫超时定时器
  /// 作用：30秒无响应自动取消通话
  void _startCallTimeout() {
    _callTimeout?.cancel();
    _callTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (_isCalling && !_isConnected) {
        // 超时未接听，自动取消
        _stopDotAnimation();
        context.showErrorToast('对方无响应');
        _cancelCall();
      }
    });
    
    // 启动动态省略号动画
    _startDotAnimation();
  }
  
  /// features/call/call_screen.dart | _startDotAnimation | 启动省略号动画
  /// 作用：让"等待对方接听"后的省略号动态变化
  void _startDotAnimation() {
    _dotTimer?.cancel();
    _dotCount = 0;
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // 0, 1, 2, 3 循环
      });
    });
  }
  
  /// features/call/call_screen.dart | _stopDotAnimation | 停止省略号动画
  /// 作用：停止省略号动画定时器
  void _stopDotAnimation() {
    _dotTimer?.cancel();
    _dotTimer = null;
  }
  
  /// features/call/call_screen.dart | _getWaitingText | 获取等待文本
  /// 作用：返回带动态省略号的等待文本
  String _getWaitingText() {
    final dots = '.' * _dotCount;
    final spaces = ' ' * (3 - _dotCount); // 保持宽度一致
    return '等待对方接听$dots$spaces';
  }
  
  /// features/call/call_screen.dart | _onCallStateChanged | 通话状态变化回调
  /// 作用：监听Provider状态变化，更新UI
  void _onCallStateChanged() {
    if (!mounted) return;
    
    final callProvider = context.read<CallProvider>();
    final room = callProvider.currentRoom;
    
    if (room == null) {
      // 通话已结束
      return;
    }
    
    setState(() {
      if (room.status == CallRoomStatus.active) {
        _isConnected = true;
        _isCalling = false;
        _isRinging = false;
        _statusText = '通话中';
        // 接通后取消超时定时器、停止铃声和省略号动画
        _callTimeout?.cancel();
        _stopDotAnimation();
        _stopRingtone();
      } else if (room.status == CallRoomStatus.ringing) {
        _statusText = '等待对方接听...';
      }
    });
  }
  
  /// features/call/call_screen.dart | _onCallEnded | 通话结束回调
  /// 作用：通话结束时关闭界面
  /// @param result 通话结果
  void _onCallEnded(CallResult result) {
    if (!mounted) return;
    // 如果正在主动结束通话，忽略此回调（防止Double Pop）
    if (_isEnding) return;
    
    // 停止省略号动画
    _stopDotAnimation();
    
    String message;
    bool isError = false;
    switch (result) {
      case CallResult.completed:
        message = '通话结束';
        break;
      case CallResult.rejected:
        message = '对方已拒绝';
        isError = true;
        break;
      case CallResult.cancelled:
        message = '通话已取消';
        break;
      case CallResult.busy:
        message = '对方忙线中';
        isError = true;
        break;
      case CallResult.missed:
        message = '未接听';
        isError = true;
        break;
      case CallResult.failed:
        message = '通话失败';
        isError = true;
        break;
    }
    
    // 使用顶部toast提示
    if (isError) {
      context.showErrorToast(message);
    } else {
      context.showSuccessToast(message);
    }
    
    Navigator.of(context).pop();
  }

  /// features/call/call_screen.dart | _answerCall | 接听通话
  /// 作用：用户点击接听按钮
  Future<void> _answerCall() async {
    // 停止铃声
    await _stopRingtone();
    
    // 先请求权限
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _permissionsGranted = true;
    
    final callProvider = context.read<CallProvider>();
    
    setState(() {
      _statusText = '正在接听...';
      _isRinging = false;
    });
    
    final room = await callProvider.answerCall(widget.roomUuid);
    
    if (room != null) {
      setState(() {
        _isConnected = true;
        _statusText = '通话中';
      });
    } else {
      _showError('接听失败');
      if (mounted) Navigator.of(context).pop();
    }
  }
  
  /// features/call/call_screen.dart | _rejectCall | 拒绝通话
  /// 作用：用户点击拒绝按钮
  Future<void> _rejectCall() async {
    // 停止铃声
    await _stopRingtone();
    
    final callProvider = context.read<CallProvider>();
    await callProvider.rejectCall(widget.roomUuid);
    if (mounted) Navigator.of(context).pop();
  }
  
  /// features/call/call_screen.dart | _cancelCall | 取消通话
  /// 作用：发起者取消呼叫
  Future<void> _cancelCall() async {
    _callTimeout?.cancel();
    // 停止铃声
    await _stopRingtone();
    
    setState(() {
      _isEnding = true;
    });
    
    final callProvider = context.read<CallProvider>();
    await callProvider.cancelCall();
    if (mounted) Navigator.of(context).pop();
  }
  
  /// features/call/call_screen.dart | _endCall | 结束通话
  /// 作用：挂断通话
  Future<void> _endCall() async {
    _callTimeout?.cancel();
    // 停止铃声
    await _stopRingtone();
    
    setState(() {
      _isEnding = true;
    });
    
    final callProvider = context.read<CallProvider>();
    await callProvider.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }
  
  /// features/call/call_screen.dart | _toggleMute | 切换静音
  /// 作用：开启/关闭麦克风
  Future<void> _toggleMute() async {
    final callProvider = context.read<CallProvider>();
    await callProvider.toggleAudio();
  }
  
  /// features/call/call_screen.dart | _toggleVideo | 切换视频
  /// 作用：开启/关闭摄像头
  Future<void> _toggleVideo() async {
    final callProvider = context.read<CallProvider>();
    await callProvider.toggleVideo();
  }
  
  /// features/call/call_screen.dart | _toggleSpeaker | 切换扬声器
  /// 作用：开启/关闭扬声器
  void _toggleSpeaker() {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    // TODO: 实际切换扬声器
  }
  
  /// features/call/call_screen.dart | _switchCamera | 切换摄像头
  /// 作用：前后摄像头切换
  Future<void> _switchCamera() async {
    final callProvider = context.read<CallProvider>();
    await callProvider.switchCamera();
  }
  
  /// features/call/call_screen.dart | _showError | 显示错误提示
  /// 作用：显示错误信息（顶部toast）
  /// @param message 错误信息
  void _showError(String message) {
    if (!mounted) return;
    context.showErrorToast(message);
  }

  @override
  Widget build(BuildContext context) {
    // 获取底部安全区域高度，用于底部按钮的padding
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      // 移除SafeArea实现真正全屏
      body: Consumer<CallProvider>(
        builder: (context, callProvider, _) {
          return Stack(
            children: [
              // 背景（视频通话时显示视频画面）
              _buildBackground(callProvider),
              
              // 主要内容
              Column(
                children: [
                  // 顶部安全区域padding
                  SizedBox(height: MediaQuery.of(context).padding.top + 20),
                  
                  // 顶部信息区域
                  _buildTopInfo(callProvider),
                  
                  const Spacer(),
                  
                  // 底部控制按钮
                  _buildControls(callProvider),
                  
                  // 底部安全区域padding
                  SizedBox(height: bottomPadding + 30),
                ],
              ),
              
              // 群聊通话时显示参与者列表
              if (widget.roomType == CallRoomType.group && _isConnected)
                _buildParticipantsList(callProvider),
            ],
          );
        },
      ),
    );
  }
  
  /// features/call/call_screen.dart | _buildBackground | 构建背景
  /// 作用：视频通话时显示视频画面，语音通话时显示渐变背景
  Widget _buildBackground(CallProvider callProvider) {
    debugPrint('[通话界面] _buildBackground: callType=${widget.callType.name}, isConnected=$_isConnected');
    
    if (widget.callType == CallType.video) {
      // 视频通话：显示本地和远程视频
      final webrtcClient = callProvider.webrtcClient;
      
      if (webrtcClient != null) {
        if (_isConnected && webrtcClient.remoteRenderer != null) {
          // 通话已连接：显示远程视频（全屏）+ 本地视频（小窗）
          return Stack(
            children: [
              // features/call/call_screen.dart | _buildVideoArea | 远程视频（全屏）
              // 作用：显示对方的视频画面，不镜像
              Positioned.fill(
                child: RTCVideoView(
                  webrtcClient.remoteRenderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false, // 远程视频不镜像
                ),
              ),
              // features/call/call_screen.dart | _buildVideoArea | 本地视频（小窗）
              // 作用：显示自己的视频画面，镜像显示（符合用户习惯）
              if (webrtcClient.localRenderer != null)
                Positioned(
                  top: 100,
                  right: 16,
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      webrtcClient.localRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: false, // 本地视频镜像
                    ),
                  ),
                ),
            ],
          );
        } else if (webrtcClient.localRenderer != null) {
          // features/call/call_screen.dart | _buildVideoArea | 本地视频预览（全屏）
          // 作用：通话未连接时，显示本地视频预览，镜像显示
          return RTCVideoView(
            webrtcClient.localRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false, // 本地预览镜像
          );
        }
      }
      
      // WebRTC未就绪时显示黑色背景
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    // 语音通话渐变背景
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
        ),
      ),
    );
  }
  
  /// features/call/call_screen.dart | _buildTopInfo | 构建顶部信息
  /// 作用：显示对方头像、名称、通话状态
  Widget _buildTopInfo(CallProvider callProvider) {
    // 获取显示信息
    String displayName;
    String? avatarUrl;
    
    if (widget.roomType == CallRoomType.group) {
      displayName = widget.groupInfo?.name ?? '群聊通话';
      avatarUrl = widget.groupInfo?.avatar;
    } else {
      displayName = widget.peerUser?.displayName ?? '通话';
      avatarUrl = widget.peerUser?.avatar;
    }
    
    // 获取状态文本（呼叫中使用动态省略号）
    String statusDisplay;
    if (_isConnected) {
      statusDisplay = callProvider.formattedDuration;
    } else if (_isCalling) {
      statusDisplay = _getWaitingText();
    } else {
      statusDisplay = _statusText;
    }
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 头像
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 3),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName),
                    )
                  : _buildDefaultAvatar(displayName),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 名称
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 状态/时长
          Text(
            statusDisplay,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  /// features/call/call_screen.dart | _buildDefaultAvatar | 构建默认头像
  /// 作用：无头像时显示默认头像
  /// @param name 名称
  Widget _buildDefaultAvatar(String name) {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// features/call/call_screen.dart | _buildControls | 构建控制按钮
  /// 作用：显示通话控制按钮（静音、挂断、视频等）
  Widget _buildControls(CallProvider callProvider) {
    debugPrint('[通话界面] _buildControls: callType=${widget.callType.name}, isRinging=$_isRinging, isCalling=$_isCalling, isConnected=$_isConnected');
    
    if (_isRinging) {
      // 来电：显示接听和拒绝按钮
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 拒绝按钮
          _buildSvgControlButton(
            svgPath: 'assets/app_icons/svg/call-slash.svg',
            label: '拒绝',
            backgroundColor: Colors.red,
            onTap: _rejectCall,
          ),
          // 接听按钮
          _buildSvgControlButton(
            svgPath: 'assets/app_icons/svg/call.svg',
            label: '接听',
            backgroundColor: Colors.green,
            onTap: _answerCall,
          ),
        ],
      );
    }
    
    if (_isCalling) {
      // 呼叫中：显示取消按钮和视频控制按钮（视频通话时）
      return Column(
        children: [
          // 视频通话时显示视频控制按钮
          if (widget.callType == CallType.video)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSvgControlButton(
                  svgPath: callProvider.localAudioEnabled 
                      ? 'assets/app_icons/svg/microphone.svg' 
                      : 'assets/app_icons/svg/microphone-slash.svg',
                  label: callProvider.localAudioEnabled ? '静音' : '取消静音',
                  backgroundColor: callProvider.localAudioEnabled ? Colors.white24 : Colors.red,
                  onTap: _toggleMute,
                ),
                _buildSvgControlButton(
                  svgPath: callProvider.localVideoEnabled 
                      ? 'assets/app_icons/svg/video.svg' 
                      : 'assets/app_icons/svg/video-slash.svg',
                  label: callProvider.localVideoEnabled ? '关闭视频' : '开启视频',
                  backgroundColor: callProvider.localVideoEnabled ? Colors.white24 : Colors.red,
                  onTap: _toggleVideo,
                ),
                _buildSvgControlButton(
                  svgPath: 'assets/app_icons/svg/camera.svg',
                  label: '切换',
                  backgroundColor: Colors.white24,
                  onTap: _switchCamera,
                ),
              ],
            ),
          
          const SizedBox(height: 30),
          
          // 取消按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSvgControlButton(
                svgPath: 'assets/app_icons/svg/call-slash.svg',
                label: '取消',
                backgroundColor: Colors.red,
                onTap: _cancelCall,
              ),
            ],
          ),
        ],
      );
    }
    
    // 通话中：显示完整控制按钮
    return Column(
      children: [
        // 第一行：静音、视频、扬声器
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSvgControlButton(
              svgPath: callProvider.localAudioEnabled 
                  ? 'assets/app_icons/svg/microphone.svg' 
                  : 'assets/app_icons/svg/microphone-slash.svg',
              label: callProvider.localAudioEnabled ? '静音' : '取消静音',
              backgroundColor: callProvider.localAudioEnabled ? Colors.white24 : Colors.red,
              onTap: _toggleMute,
            ),
            if (widget.callType == CallType.video)
              _buildSvgControlButton(
                svgPath: callProvider.localVideoEnabled 
                    ? 'assets/app_icons/svg/video.svg' 
                    : 'assets/app_icons/svg/video-slash.svg',
                label: callProvider.localVideoEnabled ? '关闭视频' : '开启视频',
                backgroundColor: callProvider.localVideoEnabled ? Colors.white24 : Colors.red,
                onTap: _toggleVideo,
              ),
            _buildSvgControlButton(
              svgPath: _speakerEnabled 
                  ? 'assets/app_icons/svg/volume-high.svg' 
                  : 'assets/app_icons/svg/volume-low.svg',
              label: _speakerEnabled ? '关闭扬声器' : '扬声器',
              backgroundColor: _speakerEnabled ? Colors.blue : Colors.white24,
              onTap: _toggleSpeaker,
            ),
            if (widget.callType == CallType.video)
              _buildSvgControlButton(
                svgPath: 'assets/app_icons/svg/camera.svg',
                label: '切换',
                backgroundColor: Colors.white24,
                onTap: _switchCamera,
              ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        // 第二行：挂断按钮
        _buildSvgControlButton(
          svgPath: 'assets/app_icons/svg/call-slash.svg',
          label: '挂断',
          backgroundColor: Colors.red,
          size: 70,
          onTap: _endCall,
        ),
      ],
    );
  }
  
  /// features/call/call_screen.dart | _buildSvgControlButton | 构建SVG控制按钮
  /// 作用：构建使用SVG图标的控制按钮（无边框美观样式）
  /// @param svgPath SVG图标路径
  /// @param label 标签
  /// @param backgroundColor 背景颜色
  /// @param size 大小
  /// @param onTap 点击回调
  Widget _buildSvgControlButton({
    required String svgPath,
    required String label,
    required Color backgroundColor,
    double size = 60,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                svgPath,
                width: size * 0.45,
                height: size * 0.45,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  /// features/call/call_screen.dart | _buildParticipantsList | 构建参与者列表
  /// 作用：群聊通话时显示参与者列表
  Widget _buildParticipantsList(CallProvider callProvider) {
    final room = callProvider.currentRoom;
    if (room == null) return const SizedBox.shrink();
    
    final participants = room.participants
        .where((p) => p.status == CallParticipantStatus.joined)
        .toList();
    
    if (participants.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${participants.length}人',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...participants.take(4).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: p.avatar != null && p.avatar!.isNotEmpty
                    ? NetworkImage(p.avatar!)
                    : null,
                child: p.avatar == null || p.avatar!.isEmpty
                    ? Text(
                        p.displayName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
            )),
            if (participants.length > 4)
              Text(
                '+${participants.length - 4}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
