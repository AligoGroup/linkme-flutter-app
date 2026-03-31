import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../widgets/custom/friend_item.dart';
import '../../widgets/common/empty_state.dart';
import '../../shared/models/user.dart';
import 'widgets/friend_requests_view.dart';

class FriendsScreen extends StatefulWidget {
  // 当提供 externalSearch 时，本页不再渲染内部搜索框，而使用外部传入的搜索值
  final ValueListenable<String>? externalSearch;
  // 可选：对外同步当前分段（0: 好友，1: 群聊）
  final ValueNotifier<int>? segmentController;
  // 是否显示内部搜索框（默认 true）。当在 AppBar 中承载搜索时，传 false。
  final bool showInternalSearch;
  // 在发起聊天前触发的回调（用于父级切回“聊天”Tab）
  final VoidCallback? onStartChat;

  const FriendsScreen({
    super.key,
    this.externalSearch,
    this.segmentController,
    this.showInternalSearch = true,
    this.onStartChat,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // 搜索框与筛选状态
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<User> _filteredFriends = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  int _tabIndex = 0; // 0: 好友, 1: 群聊（与截图一致的双段选择）
  // 新增 2: 新朋友

  @override
  void initState() {
    super.initState();
    _loadFriendsData();
    // 外部搜索监听
    widget.externalSearch?.addListener(_onExternalSearch);
    // 首次同步分段索引给外部
    widget.segmentController?.value = _tabIndex;
  }

  void _loadFriendsData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // 按用户ID刷新联系人与群聊列表（仅本页，避免影响其他页面逻辑）
    if (authProvider.user != null) {
      chatProvider.fetchFriends(authProvider.user!.id);
      chatProvider.fetchGroups(authProvider.user!.id);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filterFriends();
    });
  }

  void _onExternalSearch() {
    final v = widget.externalSearch?.value ?? '';
    if (v.toLowerCase() == _searchQuery) return;
    setState(() {
      _searchQuery = v.toLowerCase();
      _filterFriends();
    });
  }

  void _filterFriends() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final friends = chatProvider.friends;
    final groups = chatProvider.groups;

    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(friends);
      _filteredGroups = List<Map<String, dynamic>>.from(
          groups.map((e) => Map<String, dynamic>.from(e)));
      return;
    }

    _filteredFriends = friends.where((friend) {
      final q = _searchQuery;
      return (friend.nickname?.toLowerCase().contains(q) ?? false) ||
          friend.username.toLowerCase().contains(q);
    }).toList();

    _filteredGroups = groups
        .where((g) {
          final map = Map<String, dynamic>.from(g);
          final name =
              (map['name'] ?? map['groupName'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery);
        })
        .map((g) => Map<String, dynamic>.from(g))
        .toList();
  }

  @override
  void dispose() {
    widget.externalSearch?.removeListener(_onExternalSearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 注意：MainScreen 外层已包含 Scaffold 与 AppBar，这里只构建内容区域，避免二级 Scaffold 影响已有布局
    return Container(
      color: AppColors.background,
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          // 初始化过滤数据
          if (_searchQuery.isEmpty) {
            _filteredFriends = List.from(chatProvider.friends);
            _filteredGroups = List<Map<String, dynamic>>.from(
              chatProvider.groups.map((e) => Map<String, dynamic>.from(e)),
            );
          }

          return Column(
            children: [
              if (widget.showInternalSearch) _buildSearchBar(),
              _buildSegmentedTabs(),
              Expanded(
                child: _tabIndex == 0
                    ? _buildFriendsList(chatProvider)
                    : (_tabIndex == 1
                        ? _buildGroupsList(chatProvider)
                        : _buildNewFriends()),
              ),
            ],
          );
        },
      ),
    );
  }

  // 顶部的“好友/群聊”分段切换（贴近迭代后样式）
  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SegmentChip(
            label: '好友',
            selected: _tabIndex == 0,
            onTap: () {
              if (_tabIndex == 0) return;
              setState(() {
                _tabIndex = 0;
                _onSearchChanged(_searchController.text);
              });
              widget.segmentController?.value = _tabIndex;
            },
          ),
          const SizedBox(width: 12),
          _SegmentChip(
            label: '群聊',
            selected: _tabIndex == 1,
            onTap: () {
              if (_tabIndex == 1) return;
              setState(() {
                _tabIndex = 1;
                _onSearchChanged(_searchController.text);
              });
              widget.segmentController?.value = _tabIndex;
            },
          ),
          const SizedBox(width: 12),
          _SegmentChip(
            label: '新朋友',
            selected: _tabIndex == 2,
            onTap: () {
              if (_tabIndex == 2) return;
              setState(() {
                _tabIndex = 2;
              });
              widget.segmentController?.value = _tabIndex;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewFriends() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: FriendRequestsView(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: _tabIndex == 0 ? '搜索好友' : '搜索群聊',
          hintStyle:
              AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.textLight, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppColors.textLight, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFriendsList(ChatProvider chatProvider) {
    final hasList = _filteredFriends.isNotEmpty;
    // 加载中但已有列表时，优先显示列表（避免因离线刷新遮挡现有数据）
    if (chatProvider.isLoading && !hasList) {
      return const Center(
        child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)),
      );
    }

    // 不再显示错误大红字；离线/后端异常时仍展示已有好友列表。
    if (_filteredFriends.isEmpty) {
      return EmptyState(
        icon: _searchQuery.isNotEmpty ? Icons.search_off : Icons.person_add_alt,
        title: _searchQuery.isNotEmpty ? '没有找到匹配的好友' : '还没有好友',
        subtitle: _searchQuery.isNotEmpty ? '尝试使用其他关键词搜索' : '点击右上角“+”添加新朋友',
        buttonText: _searchQuery.isEmpty ? '添加好友' : null,
        onButtonPressed: _searchQuery.isEmpty ? _navigateToAddFriend : null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredFriends.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        color: AppColors.borderLight,
        indent: 68,
      ),
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        return FriendItemWithActions(
          friend: friend,
          onTap: () => _navigateToFriendProfile(friend),
          onChat: () => _startChatWithFriend(friend),
          onProfile: () => _navigateToFriendProfile(friend),
          onDelete: () => _deleteFriend(friend),
          onBlock: () => _blockFriend(friend),
        );
      },
    );
  }

  // 群聊列表（与 GroupListScreen 保持一致的后台数据对接，但样式与截图一致）
  Widget _buildGroupsList(ChatProvider chatProvider) {
    final groups = _filteredGroups;
    if (chatProvider.isLoading && groups.isEmpty) {
      return const Center(
        child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)),
      );
    }
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.group_outlined,
        title: '暂无群聊',
        subtitle: '创建或加入一个群聊开始交流',
      );
    }
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final g = groups[index];
        final name = (g['name'] ?? g['groupName'] ?? '未命名群聊').toString();
        final avatar = g['avatar'] as String?;
        final id = (g['id'] ?? g['groupId']).toString();
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.surface,
            backgroundImage: (avatar != null &&
                    avatar.isNotEmpty &&
                    !avatar.startsWith('GROUP_AVATAR:'))
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.startsWith('GROUP_AVATAR:'))
                ? const Icon(Icons.group, color: AppColors.primary)
                : null,
          ),
          title: Text(name, style: AppTextStyles.body1),
          subtitle: Text('群聊', style: AppTextStyles.caption),
          trailing: PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'info', child: Text('群信息')),
            ],
            onSelected: (v) {
              if (v == 'info') context.push('/group-info/$id');
            },
          ),
          onTap: () {
            widget.onStartChat?.call();
            context.push('/chat/$id?type=group');
          },
        );
      },
    );
  }

  void _deleteFriend(User friend) {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = authProvider.user?.id;
    if (currentUserId == null) {
      context.showErrorToast('用户未登录');
      return;
    }
    chatProvider.deleteFriend(currentUserId, friend.id).then((success) {
      if (success) {
        context.showSuccessToast('已删除好友 ${friend.nickname ?? friend.username}');
      } else {
        context.showErrorToast('删除好友失败，请重试');
      }
    });
  }

  void _blockFriend(User friend) {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = authProvider.user?.id;
    if (currentUserId == null) {
      context.showErrorToast('用户未登录');
      return;
    }
    chatProvider.blockFriend(currentUserId, friend.id).then((success) {
      if (success) {
        context.showWarningToast('已拉黑 ${friend.nickname ?? friend.username}');
      } else {
        context.showErrorToast('拉黑失败，请重试');
      }
    });
  }

  void _navigateToAddFriend() {
    try {
      if (mounted) {
        context.push('/add-friend');
      }
    } catch (e) {
      debugPrint('添加好友导航错误: $e');
      if (mounted) {
        context.showErrorToast('打开添加好友页面失败，请重试');
      }
    }
  }

  void _navigateToFriendProfile(User friend) {
    try {
      if (mounted) {
        context.push('/friend-profile/${friend.id}');
      }
    } catch (e) {
      debugPrint('好友资料导航错误: $e');
      if (mounted) {
        context.showErrorToast('打开好友资料失败，请重试');
      }
    }
  }

  void _startChatWithFriend(User friend) {
    try {
      if (mounted) {
        final chatProvider = context.read<ChatProvider>();
        widget.onStartChat?.call();
        chatProvider.ensureConversationForFriend(friend.id, friendData: friend);
        context.push('/chat/${friend.id}?type=private');
      }
    } catch (e) {
      debugPrint('开始聊天导航错误: $e');
      if (mounted) {
        context.showErrorToast('打开聊天失败，请重试');
      }
    }
  }
}

// 轻量分段选择控件，贴近截图的圆角粉色样式
class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // 更紧凑：同时减小宽高
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // 选中：浅粉背景 + 浅灰边；圆角 3px
          color: selected ? const Color(0xFFFFF0F6) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? const Color(0xFFE5E7EB) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body2.copyWith(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
