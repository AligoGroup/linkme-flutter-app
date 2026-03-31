import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/user.dart';
import '../../shared/providers/chat_provider.dart';
import 'user_avatar.dart';
import 'package:provider/provider.dart';

class FriendItem extends StatelessWidget {
  final User friend;
  final VoidCallback? onTap;
  final VoidCallback? onChatPressed;
  final VoidCallback? onLongPress;
  final bool showChatButton;
  final bool isSelected;

  const FriendItem({
    super.key,
    required this.friend,
    this.onTap,
    this.onChatPressed,
    this.onLongPress,
    this.showChatButton = true,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.1) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 头像
                // 在线状态改为读取 ChatProvider 的实时状态，
                // 若无状态则回退到 friend.status
                Consumer<ChatProvider>(
                  builder: (context, chat, _) {
                    final online = chat.isUserOnline(friend.id.toString()) ||
                        friend.status == UserStatus.online ||
                        friend.status == UserStatus.active;
                    return UserAvatar(
                      imageUrl: friend.avatar,
                      name: friend.nickname,
                      size: 44,
                      showOnlineStatus: true,
                      isOnline: online,
                    );
                  },
                ),
                
                const SizedBox(width: 12),
                
                // 好友信息
                Expanded(
                  child: Consumer<ChatProvider>(
                    builder: (context, chat, _) => _buildFriendInfo(chat.isUserOnline(friend.id.toString())),
                  ),
                ),
                
                // 发消息按钮
                if (showChatButton)
                  _buildChatButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendInfo(bool isOnline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 昵称
        Text(
          friend.nickname ?? friend.username,
          style: AppTextStyles.friendName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // 个性签名或在线状态
        if (friend.signature != null && friend.signature!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            friend.signature!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const SizedBox(height: 2),
          _buildStatusIndicator(isOnline),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator(bool isOnline) {
    Color statusColor;
    String statusText;
    if (isOnline) {
      statusColor = AppColors.online;
      statusText = '在线';
    } else {
      // 按好友自身状态给出更细颗粒提示
      switch (friend.status) {
        case UserStatus.busy:
          statusColor = AppColors.warning;
          statusText = '忙碌';
          break;
        case UserStatus.away:
          statusColor = AppColors.info;
          statusText = '离开';
          break;
        case UserStatus.active:
        case UserStatus.online:
          // 理论不会进入，因为 isOnline 为 false
          statusColor = AppColors.online;
          statusText = '在线';
          break;
        case UserStatus.offline:
          statusColor = AppColors.offline;
          statusText = '离线';
          break;
      }
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: AppTextStyles.caption.copyWith(
            color: statusColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildChatButton() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onChatPressed,
          borderRadius: BorderRadius.circular(16),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class SelectableFriendItem extends StatelessWidget {
  final User friend;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;
  final VoidCallback? onTap;
  final bool showCheckbox;

  const SelectableFriendItem({
    super.key,
    required this.friend,
    required this.isSelected,
    this.onSelectionChanged,
    this.onTap,
    this.showCheckbox = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.1) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (showCheckbox) {
              onSelectionChanged?.call(!isSelected);
            } else {
              onTap?.call();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 选择框
                if (showCheckbox)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: onSelectionChanged,
                      activeColor: AppColors.primary,
                      shape: const CircleBorder(),
                    ),
                  ),
                
                // 头像
                UserAvatar(
                  imageUrl: friend.avatar,
                  name: friend.nickname,
                  size: 44,
                  showOnlineStatus: false,
                ),
                
                const SizedBox(width: 12),
                
                // 好友信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.nickname ?? friend.username,
                        style: AppTextStyles.friendName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (friend.signature != null && friend.signature!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          friend.signature!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FriendItemWithActions extends StatelessWidget {
  final User friend;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onProfile;
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;

  const FriendItemWithActions({
    super.key,
    required this.friend,
    this.onTap,
    this.onChat,
    this.onProfile,
    this.onDelete,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('friend_${friend.id}'),
      background: _buildLeftAction(),
      secondaryBackground: _buildRightAction(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // 右滑显示更多选项
          await _showMoreActions(context);
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          // 左滑发送消息
          onChat?.call();
          return false;
        }
        return false;
      },
      child: FriendItem(
        friend: friend,
        onTap: onTap,
        onChatPressed: onChat,
        onLongPress: () => _showMoreActions(context),
      ),
    );
  }

  Widget _buildLeftAction() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      color: AppColors.primary,
      child: const Icon(
        Icons.chat_bubble,
        color: AppColors.textWhite,
        size: 24,
      ),
    );
  }

  Widget _buildRightAction() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: AppColors.textLight,
      child: const Icon(
        Icons.more_horiz,
        color: AppColors.textWhite,
        size: 24,
      ),
    );
  }

  Future<void> _showMoreActions(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('发送消息'),
              onTap: () {
                Navigator.pop(context);
                onChat?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('查看资料'),
              onTap: () {
                Navigator.pop(context);
                onProfile?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: const Text('拉黑', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.error),
              title: const Text('删除好友', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拉黑好友'),
        content: Text('确定要拉黑 ${friend.nickname} 吗？拉黑后将不能接收对方的消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onBlock?.call();
            },
            child: const Text('拉黑', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友 ${friend.nickname} 吗？删除后将从好友列表中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
