import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/call_provider.dart';
import '../../shared/models/call_session.dart';
import '../../features/call/call_screen.dart';

/// widgets/call/incoming_call_dialog.dart | IncomingCallDialog | 来电对话框
/// 作用：显示来电通知，提供接听和拒绝按钮
/// 参数：incomingCall 来电信息

class IncomingCallDialog extends StatelessWidget {
  final IncomingCallInfo incomingCall;

  const IncomingCallDialog({
    super.key,
    required this.incomingCall,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头像
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipOval(
                child: _buildAvatar(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 名称
            Text(
              incomingCall.displayTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // 通话类型
            Text(
              incomingCall.isVideo ? '视频通话' : '语音通话',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 拒绝按钮
                _buildActionButton(
                  icon: Icons.call_end,
                  label: '拒绝',
                  color: Colors.red,
                  onTap: () => _rejectCall(context),
                ),
                // 接听按钮
                _buildActionButton(
                  icon: Icons.call,
                  label: '接听',
                  color: Colors.green,
                  onTap: () => _answerCall(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// widgets/call/incoming_call_dialog.dart | _buildAvatar | 构建头像
  /// 作用：显示来电者头像
  Widget _buildAvatar() {
    String? avatarUrl;
    String displayName = incomingCall.displayTitle;
    
    if (incomingCall.roomType == CallRoomType.group) {
      avatarUrl = incomingCall.group?.avatar;
    } else {
      avatarUrl = incomingCall.caller?.avatar;
    }
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName),
      );
    }
    
    return _buildDefaultAvatar(displayName);
  }

  /// widgets/call/incoming_call_dialog.dart | _buildDefaultAvatar | 构建默认头像
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
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// widgets/call/incoming_call_dialog.dart | _buildActionButton | 构建操作按钮
  /// 作用：构建接听或拒绝按钮
  /// @param icon 图标
  /// @param label 标签
  /// @param color 颜色
  /// @param onTap 点击回调
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// widgets/call/incoming_call_dialog.dart | _answerCall | 接听通话
  /// 作用：用户点击接听按钮
  /// @param context 上下文
  Future<void> _answerCall(BuildContext context) async {
    final callProvider = context.read<CallProvider>();
    
    // 关闭对话框
    Navigator.of(context).pop();
    
    // 跳转到通话界面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          roomUuid: incomingCall.roomUuid,
          isIncoming: true,
          callType: incomingCall.callType,
          roomType: incomingCall.roomType,
          peerUser: incomingCall.caller,
          groupInfo: incomingCall.group,
        ),
      ),
    );
  }

  /// widgets/call/incoming_call_dialog.dart | _rejectCall | 拒绝通话
  /// 作用：用户点击拒绝按钮
  /// @param context 上下文
  Future<void> _rejectCall(BuildContext context) async {
    final callProvider = context.read<CallProvider>();
    
    // 拒绝通话
    await callProvider.rejectCall(incomingCall.roomUuid);
    
    // 关闭对话框
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
