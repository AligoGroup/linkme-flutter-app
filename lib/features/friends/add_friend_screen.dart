import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
// import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/user.dart';
import '../../widgets/common/empty_state.dart';
// import '../../widgets/common/loading_button.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<User> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  // 仅保留搜索入口：支持手机号 / 昵称 / 账号 / 邮箱

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加好友')),
      body: _buildSearchOnlyBody(),
    );
  }

  // 仅保留搜索框 + 结果列表
  Widget _buildSearchOnlyBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '搜索手机号 / 昵称 / 账号 / 邮箱',
              hintStyle: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textLight,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textLight,
                        size: 20,
                      ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: '搜索用户',
        subtitle: '输入手机号、昵称、账号或邮箱',
      );
    }

    if (_isSearching) {
      return const Center(
        child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)),
      );
    }

    if (_searchResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: '没有找到用户',
        subtitle: '没有找到匹配的用户，试试其他关键词',
        buttonText: '清除搜索',
        onButtonPressed: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        color: AppColors.borderLight,
        indent: 68,
      ),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildSearchResultItem(user);
      },
    );
  }

  Widget _buildSearchResultItem(User user) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final isFriend = chatProvider.friends.any((friend) => friend.id == user.id);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
            backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
            child: user.avatar == null
                ? Text(
                    (user.nickname?.isNotEmpty ?? false) ? user.nickname![0] : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname ?? user.username,
                  style: AppTextStyles.friendName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (user.signature != null && user.signature!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.signature!,
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
          
          if (isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '已添加',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _sendFriendRequest(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('添加', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    if (_searchQuery.length < 2) return;

    _performSearch(_searchQuery);
  }

  void _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final results = await chatProvider.searchUsers(query);
      
      if (mounted && _searchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        context.showErrorToast('搜索失败: $e');
      }
    }
  }

  void _sendFriendRequest(User user) {
    final auth = context.read<ChatProvider>();
    final me = context.read<AuthProvider>().user;
    if (me == null) { context.showErrorToast('未登录'); return; }
    auth.sendFriendRequest(me.id, user.id).then((ok) {
      if (ok) context.showSuccessToast('已向 ${user.nickname ?? user.username} 发送好友请求');
      else context.showErrorToast('发送失败，请稍后重试');
    });
  }

}
