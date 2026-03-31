import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/zennotes_invitation_provider.dart';
import '../../shared/models/zennotes_invitation.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../core/theme/app_colors.dart';

/// zennotes_invitations_screen.dart | ZenNotesInvitationsScreen | ZenNotes邀请通知列表页面
/// 展示所有笔记本协作邀请，用户可以查看邀请详情并跳转到笔记本
class ZenNotesInvitationsScreen extends StatefulWidget {
  const ZenNotesInvitationsScreen({super.key});

  @override
  State<ZenNotesInvitationsScreen> createState() =>
      _ZenNotesInvitationsScreenState();
}

class _ZenNotesInvitationsScreenState extends State<ZenNotesInvitationsScreen> {
  @override
  void initState() {
    super.initState();
    // 进入页面时标记所有邀请为已读
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ZenNotesInvitationProvider>().markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ZenNotes 邀请',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<ZenNotesInvitationProvider>(
            builder: (context, provider, _) {
              if (provider.invitations.isEmpty) return const SizedBox.shrink();

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _showClearAllDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('清空所有邀请'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ZenNotesInvitationProvider>(
        builder: (context, provider, _) {
          if (provider.invitations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: provider.invitations.length,
            itemBuilder: (context, index) {
              final invitation = provider.invitations[index];
              return _InvitationCard(
                invitation: invitation,
                onTap: () => _handleInvitationTap(invitation),
                onDismiss: () => _handleDismiss(invitation),
              );
            },
          );
        },
      ),
    );
  }

  /// zennotes_invitations_screen.dart | _ZenNotesInvitationsScreenState | _buildEmptyState | 构建空状态视图
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F8),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 60,
              color: Color(0xFFB0B8C8),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无邀请通知',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '当有人邀请您协作编辑笔记本时\n邀请通知会显示在这里',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black38,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// zennotes_invitations_screen.dart | _ZenNotesInvitationsScreenState | _handleInvitationTap | invitation
  /// 处理邀请卡片点击，跳转到笔记本页面
  void _handleInvitationTap(ZenNotesInvitation invitation) {
    // 标记为已读
    context.read<ZenNotesInvitationProvider>().markAsRead(invitation.id);

    // 跳转到笔记本页面
    context.push('/notes');
  }

  /// zennotes_invitations_screen.dart | _ZenNotesInvitationsScreenState | _handleDismiss | invitation
  /// 处理邀请卡片滑动删除
  void _handleDismiss(ZenNotesInvitation invitation) {
    context.read<ZenNotesInvitationProvider>().removeInvitation(invitation.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已删除邀请'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            // 这里可以实现撤销功能，需要暂存被删除的邀请
          },
        ),
      ),
    );
  }

  /// zennotes_invitations_screen.dart | _ZenNotesInvitationsScreenState | _showClearAllDialog
  /// 显示清空所有邀请的确认对话框
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有邀请'),
        content: const Text('确定要清空所有邀请通知吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ZenNotesInvitationProvider>().clearAll();
              Navigator.of(context).pop();
            },
            child: const Text(
              '清空',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// zennotes_invitations_screen.dart | _InvitationCard | 邀请卡片组件
/// 展示单个邀请的详细信息
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onTap,
    required this.onDismiss,
  });

  final ZenNotesInvitation invitation;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(invitation.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 邀请人头像
              UserAvatar(
                imageUrl: invitation.inviterAvatar,
                name: invitation.inviterName,
                size: 48,
              ),
              const SizedBox(width: 12),
              // 邀请信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 邀请人和笔记本标题
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: invitation.inviterName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' 邀请您协作编辑笔记本\n'),
                          TextSpan(
                            text: '「${invitation.notebookTitle}」',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 权限和时间
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F5FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            invitation.permissionText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2B69FF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          invitation.timeDisplay,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 右箭头
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
