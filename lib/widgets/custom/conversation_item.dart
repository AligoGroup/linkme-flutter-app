import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/message.dart';
import '../../shared/models/user.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import 'user_avatar.dart';
import 'group_avatar.dart';
import 'package:linkme_flutter/widgets/common/unread_badge.dart';

class ConversationItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const ConversationItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use a Stack to overlay an unread badge on the top-right corner
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          // 置顶会话使用浅粉背景；选中时在其基础上稍微加深
          decoration: BoxDecoration(
            color: conversation.isPinned
                ? AppColors.primaryLight
                    .withValues(alpha: isSelected ? 0.18 : 0.12)
                : (isSelected
                    ? AppColors.primaryLight.withValues(alpha: 0.10)
                    : null),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // 头像
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    // 会话信息
                    Expanded(child: _buildConversationInfo()),
                    const SizedBox(width: 8),
                    // 右侧信息（时间、静音图标）
                    _buildRightInfo(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Top-right unread badge (red)
        if (conversation.unreadCount > 0)
          Positioned(
            right: 16,
            top: 8,
            child: IgnorePointer(
              child: UnreadBadge(count: conversation.unreadCount),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (conversation.type == ConversationType.group) {
      // 群聊头像
      return GroupAvatar(
        memberAvatars: conversation.participants
            .map((user) => user.avatar ?? '')
            .where((avatar) => avatar.isNotEmpty)
            .toList(),
        groupName: conversation.name,
        size: 50,
        groupAvatar: conversation.avatar,
      );
    } else {
      // 私聊头像
      return Consumer2<AuthProvider, ChatProvider>(
        builder: (context, authProvider, chatProvider, _) {
          // 获取当前用户ID
          final currentUserId = authProvider.user?.id ?? 1;

          if (conversation.participants.isEmpty) {
            // 如果参与者为空，使用会话的头像和名称
            print('⚠️ 会话 ${conversation.id} 参与者为空，使用默认信息');
            return UserAvatar(
              imageUrl: conversation.avatar,
              name: conversation.name,
              size: 50,
              showOnlineStatus: false,
              isOnline: false,
            );
          }

          // 找到对话中的其他用户（不是当前用户）
          final otherUser = conversation.participants.firstWhere(
            (user) => user.id != currentUserId,
            orElse: () => conversation.participants.first, // 安全fallback
          );

          print(
              '👤 显示用户头像: ${otherUser.nickname ?? otherUser.username}, 头像: ${otherUser.avatar}');

          final online = chatProvider.isUserOnline(otherUser.id.toString()) ||
              otherUser.status == UserStatus.online ||
              otherUser.status == UserStatus.active;
          return UserAvatar(
            imageUrl: otherUser.avatar,
            name: otherUser.nickname ?? otherUser.username,
            size: 50,
            showOnlineStatus: true,
            isOnline: online,
          );
        },
      );
    }
  }

  Widget _buildConversationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：会话名称和置顶图标
        Row(
          children: [
            // 置顶图标
            if (conversation.isPinned)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.push_pin,
                  size: 14,
                  color: AppColors.textLight,
                ),
              ),

            // 会话名称
            Expanded(
              child: Text(
                conversation.displayName,
                style: AppTextStyles.friendName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        // 第二行：最后消息内容
        Row(
          children: [
            if (_isLastMessageFailed())
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child:
                    Icon(Icons.error_rounded, size: 14, color: AppColors.error),
              ),
            Expanded(
              child: Text(
                conversation.lastMessageText,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时间
        Text(
          conversation.timeDisplay,
          style: AppTextStyles.caption.copyWith(
            color: conversation.unreadCount > 0
                ? AppColors.primary
                : AppColors.textLight,
          ),
        ),

        const SizedBox(height: 4),

        // 静音图标
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 静音图标
            if (conversation.isMuted)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.volume_off,
                  size: 14,
                  color: AppColors.textLight,
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _isLastMessageFailed() {
    final status = conversation.lastMessage?.sendStatus;
    return status == MessageSendStatus.failedOffline ||
        status == MessageSendStatus.failedServer;
  }
}

// 会话列表项的滑动操作
class ConversationItemWithActions extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onMute;
  final bool isSelected;

  const ConversationItemWithActions({
    super.key,
    required this.conversation,
    this.onTap,
    this.onDelete,
    this.onPin,
    this.onMute,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('conversation_${conversation.id}'),
      background: _buildLeftAction(),
      secondaryBackground: _buildRightAction(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // 右滑删除
          return await _showDeleteConfirmation(context);
        } else if (direction == DismissDirection.startToEnd) {
          // 左滑置顶/取消置顶
          onPin?.call();
          return false; // 不删除项目
        }
        return false;
      },
      // 右键菜单仅在 macOS 桌面端启用；其余端保持移动端行为
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          final isMacDesktop =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
          if (isMacDesktop) {
            _showDesktopContextMenu(context, details.globalPosition);
          }
        },
        child: ConversationItem(
          conversation: conversation,
          onTap: onTap,
          onLongPress: () => _showMoreActions(context),
          isSelected: isSelected,
        ),
      ),
    );
  }

  Widget _buildLeftAction() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      color: conversation.isPinned ? AppColors.textLight : AppColors.primary,
      child: Icon(
        conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        color: AppColors.textWhite,
        size: 24,
      ),
    );
  }

  Widget _buildRightAction() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: AppColors.error,
      child: const Icon(
        Icons.delete,
        color: AppColors.textWhite,
        size: 24,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除会话'),
            content: Text('确定要删除与 ${conversation.displayName} 的会话吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onDelete?.call();
                },
                child:
                    const Text('删除', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMoreActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
              ),
              title: Text(conversation.isPinned ? '取消置顶' : '置顶聊天'),
              onTap: () {
                Navigator.pop(context);
                onPin?.call();
              },
            ),
            ListTile(
              leading: Icon(
                conversation.isMuted ? Icons.volume_up : Icons.volume_off,
              ),
              title: Text(conversation.isMuted ? '取消静音' : '消息免打扰'),
              onTap: () {
                Navigator.pop(context);
                onMute?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title:
                  const Text('删除聊天', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showDeleteConfirmation(context);
                if (confirm) {
                  onDelete?.call();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 桌面端专用：右键上下文菜单（竖向列表 + 浅粉背景），样式与聊天页面一致
  void _showDesktopContextMenu(BuildContext context, Offset globalPos) {
    final Size screen = MediaQuery.of(context).size;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset anchor = overlay.globalToLocal(globalPos);

    const double menuWidth = 132; // 与聊天页保持一致
    const double padding = 12;
    final double left =
        (anchor.dx + 8).clamp(padding, screen.width - menuWidth - padding);
    final double top = (anchor.dy - 8).clamp(80, screen.height - 240);

    final actions = <_DesktopAction>[
      _DesktopAction(
        icon: conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        label: conversation.isPinned ? '取消置顶' : '置顶聊天',
        onTap: () => onPin?.call(),
      ),
      _DesktopAction(
        icon: conversation.isMuted ? Icons.volume_up : Icons.volume_off,
        label: conversation.isMuted ? '取消静音' : '消息免打扰',
        onTap: () => onMute?.call(),
      ),
      _DesktopAction(
        icon: Icons.delete_outline_rounded,
        label: '删除聊天',
        danger: true,
        onTap: () async {
          final ok = await _showDeleteConfirmation(context);
          if (ok) onDelete?.call();
        },
      ),
    ];

    showGeneralDialog(
      context: context,
      barrierLabel: 'conversation_ctx',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (_, __, ___) {
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFF5F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE3F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.shadowMedium,
                        blurRadius: 10,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in actions)
                      _buildDesktopMenuItem(
                        icon: a.icon,
                        label: a.label,
                        danger: a.danger,
                        onTap: () {
                          Navigator.of(context).pop();
                          a.onTap();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildDesktopMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0x1F000000), // 悬停高亮
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: danger ? AppColors.error : AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: danger ? AppColors.error : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 简单的动作数据结构
class _DesktopAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  _DesktopAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});
}
