import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/user.dart';
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/lottie_refresh_indicator.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _groupInfo;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final groupInfo = await chatProvider
          .getGroupDetailWithMembers(int.parse(widget.groupId));

      if (mounted) {
        setState(() {
          _groupInfo = groupInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        context.showErrorToast('加载群信息失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群聊信息'),
        actions: [
          if (_groupInfo != null)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('编辑群信息'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_member',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('添加成员'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('退出群聊', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                if (_isGroupOwner())
                  const PopupMenuItem(
                    value: 'dissolve',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('解散群聊', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)))
          : _groupInfo == null
              ? const Center(child: Text('加载群信息失败'))
              : _buildGroupInfo(),
    );
  }

  Widget _buildGroupInfo() {
    final groupInfo = _groupInfo!;
    final members = (groupInfo['members'] as List<dynamic>?) ?? [];

    return LottieRefreshIndicator(
      onRefresh: _loadGroupInfo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 群聊头像和基本信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 群聊头像
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(40),
                      image: (groupInfo['avatar'] != null &&
                              !(groupInfo['avatar'] as String)
                                  .startsWith('GROUP_AVATAR:'))
                          ? DecorationImage(
                              image: NetworkImage(groupInfo['avatar']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (groupInfo['avatar'] == null ||
                            (groupInfo['avatar'] as String)
                                .startsWith('GROUP_AVATAR:'))
                        ? const Icon(
                            Icons.group,
                            size: 40,
                            color: AppColors.textLight,
                          )
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // 群聊名称（兼容后端字段 name）
                  Text(
                    groupInfo['groupName'] ?? groupInfo['name'] ?? '未知群聊',
                    style: AppTextStyles.h4,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // 群聊ID
                  Text(
                    '群聊ID: ${widget.groupId}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),

                  // 展示群公告（后端字段为 announcement）；兼容旧字段 description
                  if ((groupInfo['announcement'] ?? groupInfo['description']) !=
                          null &&
                      (groupInfo['announcement'] ?? groupInfo['description'])
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      (groupInfo['announcement'] ?? groupInfo['description'])
                          .toString(),
                      style: AppTextStyles.body2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 群成员
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.people),
                      const SizedBox(width: 8),
                      Text(
                        '群成员 (${members.length})',
                        style: AppTextStyles.h6,
                      ),
                      const Spacer(),
                      if (_isGroupOwner() || _isGroupAdmin())
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: () => _handleMenuAction('add_member'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...members.map((member) => _buildMemberItem(member)).toList(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 群聊设置
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('消息免打扰'),
                  trailing: Switch(
                    value: false, // TODO: 从群设置中获取
                    onChanged: (value) {
                      // TODO: 实现消息免打扰功能
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.push_pin),
                  title: const Text('置顶聊天'),
                  trailing: Switch(
                    value: false, // TODO: 从会话设置中获取
                    onChanged: (value) {
                      // TODO: 实现置顶聊天功能
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 操作按钮
          if (_isGroupOwner()) ...[
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed:
                    _isUpdating ? null : () => _handleMenuAction('dissolve'),
                isLoading: _isUpdating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('解散群聊'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed:
                    _isUpdating ? null : () => _handleMenuAction('leave'),
                isLoading: _isUpdating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('退出群聊'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;

    // 兼容后端返回的 GroupMember 结构（包含 user 对象）以及前端扁平化后的结构
    final user = member['user'] is Map<String, dynamic>
        ? member['user'] as Map<String, dynamic>
        : null;
    final dynamic idRaw = member['id'] ?? member['userId'] ?? user?['id'];
    final int? uid =
        idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '');
    final String? nickname = member['nickname'] ?? user?['nickname'];
    final String? username = member['username'] ?? user?['username'];
    final String? avatar = member['avatar'] ?? user?['avatar'];
    final role = (member['role'] ?? member['memberRole'] ?? 'MEMBER')
        .toString()
        .toUpperCase();

    final isCurrentUser = uid == currentUserId;
    final isOwner = role == 'OWNER';
    final isAdmin = role == 'ADMIN';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
        child: (avatar == null || avatar.isEmpty)
            ? Text((nickname ?? username ?? '?').toString().substring(0, 1))
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(nickname ?? username ?? '未知用户'),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '群主',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            )
          else if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '管理员',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
      subtitle: isCurrentUser ? const Text('我') : null,
      trailing:
          (_isGroupOwner() || _isGroupAdmin()) && !isCurrentUser && !isOwner
              ? PopupMenuButton<String>(
                  onSelected: (action) => _handleMemberAction(action, member),
                  itemBuilder: (context) => [
                    if (!isAdmin && _isGroupOwner())
                      const PopupMenuItem(
                        value: 'make_admin',
                        child: Text('设为管理员'),
                      ),
                    if (isAdmin && _isGroupOwner())
                      const PopupMenuItem(
                        value: 'remove_admin',
                        child: Text('取消管理员'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('移出群聊', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                )
              : null,
    );
  }

  bool _isGroupOwner() {
    if (_groupInfo == null) return false;
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final ownerIdRaw = _groupInfo!['ownerId'] ??
        (_groupInfo!['owner'] is Map<String, dynamic>
            ? _groupInfo!['owner']['id']
            : null);
    if (ownerIdRaw == null) return false;
    final ownerId = ownerIdRaw is num
        ? ownerIdRaw.toInt()
        : int.tryParse(ownerIdRaw.toString());
    return ownerId == currentUserId;
  }

  bool _isGroupAdmin() {
    if (_groupInfo == null) return false;
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final members = (_groupInfo!['members'] as List<dynamic>?) ?? [];
    for (final m in members) {
      final mm = m as Map<String, dynamic>;
      final user = mm['user'] is Map<String, dynamic>
          ? mm['user'] as Map<String, dynamic>
          : null;
      final dynamic idRaw = mm['id'] ?? mm['userId'] ?? user?['id'];
      final int? uid =
          idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '');
      final role =
          (mm['role'] ?? mm['memberRole'] ?? '').toString().toUpperCase();
      if (uid == currentUserId && role == 'ADMIN') return true;
    }
    return false;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editGroupInfo();
        break;
      case 'add_member':
        _addMembers();
        break;
      case 'leave':
        _leaveGroup();
        break;
      case 'dissolve':
        _dissolveGroup();
        break;
    }
  }

  void _handleMemberAction(String action, Map<String, dynamic> member) {
    switch (action) {
      case 'make_admin':
        // TODO: 实现设为管理员
        break;
      case 'remove_admin':
        // TODO: 实现取消管理员
        break;
      case 'remove':
        _removeMember(member);
        break;
    }
  }

  void _editGroupInfo() {
    if (_groupInfo == null) return;
    final info = _groupInfo!;
    final nameController =
        TextEditingController(text: info['groupName'] ?? info['name'] ?? '');
    final descController = TextEditingController(
        text: info['description'] ?? info['announcement'] ?? '');
    final avatarController = TextEditingController(text: info['avatar'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑群信息'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '群名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '公告/描述',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: avatarController,
                decoration: const InputDecoration(
                  labelText: '群头像URL',
                  hintText: 'https://example.com/avatar.png',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isUpdating = true);

              try {
                final chat = context.read<ChatProvider>();
                final updated = await chat.updateGroupInfo(
                  groupId: int.parse(widget.groupId),
                  operatorId: context.read<AuthProvider>().user!.id,
                  groupName: nameController.text.trim().isEmpty
                      ? null
                      : nameController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  avatar: avatarController.text.trim().isEmpty
                      ? null
                      : avatarController.text.trim(),
                );
                if (updated != null) {
                  if (mounted) context.showSuccessToast('群信息已更新');
                  await _loadGroupInfo();
                } else {
                  if (mounted) context.showErrorToast('更新失败，请稍后再试');
                }
              } catch (e) {
                if (mounted) context.showErrorToast('更新失败: $e');
              } finally {
                if (mounted) setState(() => _isUpdating = false);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _addMembers() async {
    final chatProvider = context.read<ChatProvider>();
    final friends = chatProvider.friends;

    if (friends.isEmpty) {
      context.showErrorToast('暂无好友可添加');
      return;
    }

    // 过滤掉已经在群里的成员
    final members = (_groupInfo!['members'] as List<dynamic>?) ?? [];
    final memberIds = members.map((m) => m['id']).toSet();
    final availableFriends =
        friends.where((f) => !memberIds.contains(f.id)).toList();

    if (availableFriends.isEmpty) {
      context.showErrorToast('所有好友都已在群中');
      return;
    }

    final selectedMembers = await showDialog<List<User>>(
      context: context,
      builder: (context) => _MemberSelectionDialog(
        friends: availableFriends,
        selectedMembers: const [],
      ),
    );

    if (selectedMembers != null && selectedMembers.isNotEmpty) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final authProvider = context.read<AuthProvider>();
        final memberIds = selectedMembers.map((m) => m.id).toList();

        final success = await chatProvider.addGroupMembers(
          int.parse(widget.groupId),
          memberIds,
          authProvider.user!.id,
        );

        if (success) {
          context.showSuccessToast('添加成员成功');
          await _loadGroupInfo(); // 刷新群信息
        } else {
          context.showErrorToast(chatProvider.errorMessage ?? '添加成员失败');
        }
      } catch (e) {
        context.showErrorToast('添加成员失败: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
      }
    }
  }

  void _removeMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出群聊'),
        content:
            Text('确定要将 ${member['nickname'] ?? member['username']} 移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final authProvider = context.read<AuthProvider>();
        final chatProvider = context.read<ChatProvider>();

        final success = await chatProvider.removeGroupMember(
          int.parse(widget.groupId),
          member['id'],
          authProvider.user!.id,
        );

        if (success) {
          context.showSuccessToast('移出成员成功');
          await _loadGroupInfo(); // 刷新群信息
        } else {
          context.showErrorToast(chatProvider.errorMessage ?? '移出成员失败');
        }
      } catch (e) {
        context.showErrorToast('移出成员失败: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
      }
    }
  }

  void _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('确定要退出这个群聊吗？退出后将无法接收群消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final authProvider = context.read<AuthProvider>();
        final chatProvider = context.read<ChatProvider>();

        final success = await chatProvider.leaveGroup(
          int.parse(widget.groupId),
          authProvider.user!.id,
        );

        if (success) {
          context.showSuccessToast('已退出群聊');
          if (mounted) {
            context.go('/'); // 返回主页
          }
        } else {
          context.showErrorToast(chatProvider.errorMessage ?? '退出群聊失败');
        }
      } catch (e) {
        context.showErrorToast('退出群聊失败: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
      }
    }
  }

  void _dissolveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散群聊'),
        content: const Text('确定要解散这个群聊吗？解散后所有成员都将无法继续使用此群聊，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('解散'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        final authProvider = context.read<AuthProvider>();
        final chatProvider = context.read<ChatProvider>();

        final success = await chatProvider.dissolveGroup(
          int.parse(widget.groupId),
          authProvider.user!.id,
        );

        if (success) {
          context.showSuccessToast('群聊已解散');
          if (mounted) {
            context.go('/'); // 返回主页
          }
        } else {
          context.showErrorToast(chatProvider.errorMessage ?? '解散群聊失败');
        }
      } catch (e) {
        context.showErrorToast('解散群聊失败: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
      }
    }
  }
}

// 成员选择对话框（复用创建群聊的组件）
class _MemberSelectionDialog extends StatefulWidget {
  final List<User> friends;
  final List<User> selectedMembers;

  const _MemberSelectionDialog({
    required this.friends,
    required this.selectedMembers,
  });

  @override
  State<_MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<_MemberSelectionDialog> {
  late List<User> _selectedMembers;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.selectedMembers);
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = widget.friends.where((friend) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (friend.nickname?.toLowerCase().contains(query) ?? false) ||
          friend.username.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('选择要添加的成员'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 搜索框
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索好友',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // 已选择的成员数量
            if (_selectedMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '已选择 ${_selectedMembers.length} 人',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),

            // 好友列表
            Expanded(
              child: ListView.builder(
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend = filteredFriends[index];
                  final isSelected = _selectedMembers.contains(friend);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedMembers.add(friend);
                        } else {
                          _selectedMembers.remove(friend);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: friend.avatar != null
                              ? NetworkImage(friend.avatar!)
                              : null,
                          child: friend.avatar == null
                              ? Text(friend.nickname?.substring(0, 1) ??
                                  friend.username.substring(0, 1))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friend.nickname ?? friend.username),
                              if (friend.nickname != null)
                                Text(
                                  friend.username,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedMembers),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
