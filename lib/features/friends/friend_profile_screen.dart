import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/user.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../shared/providers/chat_provider.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/services/friendship_service.dart';
import '../../shared/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class FriendProfileScreen extends StatefulWidget {
  final User user;
  final bool isFriend;

  const FriendProfileScreen({
    super.key,
    required this.user,
    this.isFriend = true,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  bool _isFriend = true;
  bool _isMuted = false;
  bool _isStarred = false;
  bool _isLoading = false;
  bool _isBlocked = false;
  User? _currentUser;
  final FriendshipService _friendshipService = FriendshipService();

  @override
  void initState() {
    super.initState();
    _isFriend = widget.isFriend;
    _currentUser = widget.user;
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chatProvider = Provider.of<ChatProvider>(context);
    final latest = chatProvider.isFriendBlocked(widget.user.id);
    if (latest != _isBlocked) {
      setState(() {
        _isBlocked = latest;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _friendshipService.getUserProfile(widget.user.id);
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载用户资料失败: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        context.showErrorToast('加载用户资料失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildUserInfo(),
                _buildActionButtons(),
                _buildDangerZone(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                if (_isLoading)
                  const SizedBox(height: 26, child: LinkMeLoader(fontSize: 16))
                else ...[
                  Consumer<ChatProvider>(
                    builder: (context, chat, _) {
                      final online = _currentUser != null
                          ? chat.isUserOnline(_currentUser!.id.toString()) ||
                              _currentUser!.status == UserStatus.online ||
                              _currentUser!.status == UserStatus.active
                          : false;
                      return UserAvatar(
                        imageUrl: _currentUser?.avatar,
                        name: _currentUser?.nickname ??
                            _currentUser?.username ??
                            'Unknown',
                        size: 100,
                        showOnlineStatus: true,
                        isOnline: online,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser?.nickname ??
                        _currentUser?.username ??
                        'Unknown',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_currentUser?.username ?? 'unknown'}',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.textWhite.withValues(alpha: 0.8),
                    ),
                  ),
                  if (_currentUser?.signature != null &&
                      _currentUser!.signature!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _currentUser!.signature!,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textWhite.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'star',
              child: Row(
                children: [
                  Icon(_isStarred ? Icons.star : Icons.star_border),
                  const SizedBox(width: 8),
                  Text(_isStarred ? '取消特别关心' : '特别关心'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'mute',
              child: Row(
                children: [
                  Icon(_isMuted ? Icons.volume_up : Icons.volume_off),
                  const SizedBox(width: 8),
                  Text(_isMuted ? '取消免打扰' : '消息免打扰'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report_outlined),
                  SizedBox(width: 8),
                  Text('举报'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentUser != null) ...[
            _buildInfoRow('昵称', _currentUser!.nickname ?? '未设置'),
            const Divider(height: 24, color: AppColors.borderLight),
            _buildInfoRow('用户名', '@${_currentUser!.username}', canCopy: true),
            if (_currentUser!.phone != null) ...[
              const Divider(height: 24, color: AppColors.borderLight),
              _buildInfoRow('手机号', _currentUser!.phone!, canCopy: true),
            ],
            const Divider(height: 24, color: AppColors.borderLight),
            _buildInfoRow('邮箱', _currentUser!.email, canCopy: true),
            const Divider(height: 24, color: AppColors.borderLight),
            _buildStatusRow(),
          ] else
            const Center(child: Text('用户信息加载中...')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body2,
          ),
        ),
        if (canCopy)
          GestureDetector(
            onTap: () => _copyToClipboard(value),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.copy,
                size: 16,
                color: AppColors.textLight,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusRow() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_currentUser?.status ?? UserStatus.offline) {
      case UserStatus.active:
      case UserStatus.online:
        statusColor = AppColors.online;
        statusText = '在线';
        statusIcon = Icons.circle;
        break;
      case UserStatus.busy:
        statusColor = AppColors.warning;
        statusText = '忙碌';
        statusIcon = Icons.do_not_disturb;
        break;
      case UserStatus.away:
        statusColor = AppColors.info;
        statusText = '离开';
        statusIcon = Icons.access_time;
        break;
      case UserStatus.offline:
        statusColor = AppColors.offline;
        statusText = '离线';
        statusIcon = Icons.circle;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '状态',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Icon(
          statusIcon,
          size: 12,
          color: statusColor,
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: AppTextStyles.body2.copyWith(
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final canChat = _isFriend && !_isBlocked;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canChat ? _startChat : _showChatDisabledToast,
              icon: const Icon(Icons.chat_bubble),
              label: const Text('发消息'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canChat ? _makeCall : _showChatDisabledToast,
              icon: const Icon(Icons.videocam),
              label: const Text('视频通话'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    if (!_isFriend) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理',
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.block,
              color: AppColors.error.withValues(alpha: _isBlocked ? 0.6 : 1),
            ),
            title: Text(_isBlocked ? '已拉黑' : '拉黑'),
            subtitle: Text(
              _isBlocked ? '已拉黑，对方消息将被阻止' : '拉黑后双方将无法互相发送消息，但仍保留好友关系',
            ),
            onTap: _isBlocked ? _showBlockedTip : _showBlockDialog,
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_remove, color: AppColors.error),
            title: const Text('删除好友'),
            subtitle: const Text('删除后将从好友列表中移除'),
            onTap: _showDeleteFriendDialog,
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'star':
        setState(() {
          _isStarred = !_isStarred;
        });
        context.showSuccessToast(_isStarred ? '已设置特别关心' : '已取消特别关心');
        break;
      case 'mute':
        setState(() {
          _isMuted = !_isMuted;
        });
        context.showSuccessToast(_isMuted ? '已开启免打扰' : '已关闭免打扰');
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    context.showSuccessToast('已复制到剪贴板');
  }

  void _startChat() {
    try {
      if (mounted && _currentUser != null) {
        final chatProvider = context.read<ChatProvider>();
        chatProvider.ensureConversationForFriend(_currentUser!.id,
            friendData: _currentUser);
        context.push('/chat/${_currentUser!.id}?type=private');
      }
    } catch (e) {
      debugPrint('开始聊天导航错误: $e');
      if (mounted) {
        context.showErrorToast('打开聊天失败，请重试');
      }
    }
  }

  void _makeCall() {
    context.showInfoToast('视频通话功能即将开放');
  }

  void _showChatDisabledToast() {
    if (_isBlocked) {
      context.showWarningToast('已拉黑该好友，无法发送消息');
    } else if (!_isFriend) {
      context.showWarningToast('已解除好友关系，请重新添加后再聊天');
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拉黑好友'),
        content: Text(
            '确定要拉黑 ${_currentUser?.nickname ?? _currentUser?.username} 吗？拉黑后双方将无法互相发送消息，但仍保留好友关系。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _blockFriend();
            },
            child: const Text('拉黑', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showBlockedTip() {
    context.showInfoToast('已拉黑该好友，如需解除请在设置或后台中操作');
  }

  void _showDeleteFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text(
            '确定要删除好友 ${_currentUser?.nickname ?? _currentUser?.username} 吗？删除后将从好友列表中移除，但聊天记录会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFriend();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('举报用户'),
        content: Text(
            '举报 ${_currentUser?.nickname ?? _currentUser?.username} 的不当行为'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.showSuccessToast('举报已提交，我们会尽快处理');
            },
            child: const Text('举报', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _blockFriend() async {
    if (_currentUser == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;
      if (currentUserId == null) {
        if (mounted) {
          context.showErrorToast('用户未登录');
        }
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      final success =
          await chatProvider.blockFriend(currentUserId, _currentUser!.id);
      if (mounted) {
        if (success) {
          setState(() {
            _isBlocked = true;
          });
          context.showWarningToast(
              '已拉黑 ${_currentUser!.nickname ?? _currentUser!.username}');
        } else {
          context.showErrorToast('拉黑失败，请重试');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('拉黑失败：$e');
      }
    }
  }

  void _deleteFriend() async {
    if (_currentUser == null) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;
      if (currentUserId == null) {
        if (mounted) {
          context.showErrorToast('用户未登录');
        }
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      final success =
          await chatProvider.deleteFriend(currentUserId, _currentUser!.id);
      if (mounted) {
        if (success) {
          setState(() {
            _isFriend = false;
            _isBlocked = false;
          });
          context.showSuccessToast(
              '已删除好友 ${_currentUser!.nickname ?? _currentUser!.username}');
        } else {
          context.showErrorToast('删除好友失败，请重试');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('删除好友失败：$e');
      }
    }
  }
}
