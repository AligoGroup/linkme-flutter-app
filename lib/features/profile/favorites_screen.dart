import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/favorite_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/favorite.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/custom/favorite_display.dart';
import '../../widgets/common/lottie_refresh_indicator.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Favorite> _filteredFavorites = [];
  bool _isSearching = false;
  double? _dragStartX;
  bool _didTriggerBack = false;

  final List<FavoriteType> _tabs = [
    FavoriteType.message,
    FavoriteType.link,
    FavoriteType.text,
  ];

  final Map<FavoriteType, String> _tabNames = {
    FavoriteType.message: '消息',
    FavoriteType.link: '链接',
    FavoriteType.text: '文本',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 加载收藏数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<FavoriteProvider>().loadFavorites(authProvider.user!.id);
      }
    });

    // 监听搜索输入
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final provider = context.read<FavoriteProvider>();

    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredFavorites = provider.searchFavorites(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _dragStartX = details.globalPosition.dx;
        _didTriggerBack = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_didTriggerBack) return;
        if ((_dragStartX ?? 0) < 72 && (details.primaryDelta ?? 0) > 14) {
          _didTriggerBack = true;
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _handleBack,
          ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '搜索收藏...',
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                )
              : const Text('我的收藏'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          ],
          bottom: _isSearching
              ? null
              : TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  dividerColor: Colors.transparent,
                  tabs: _tabs
                      .map(
                        (type) => Tab(
                          text: _tabNames[type],
                        ),
                      )
                      .toList(),
                ),
        ),
        body: Consumer<FavoriteProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const LoadingState(message: '加载收藏中...');
            }

            if (provider.errorMessage != null) {
              return ErrorState(
                title: '加载失败',
                message: provider.errorMessage,
                buttonText: '重试',
                onRetry: () {
                  final authProvider = context.read<AuthProvider>();
                  if (authProvider.user != null) {
                    provider.loadFavorites(authProvider.user!.id);
                  }
                },
              );
            }

            if (_isSearching) {
              return _buildSearchResults();
            }

            return TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((type) => _buildFavoriteList(provider, type))
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredFavorites.isEmpty) {
      return const EmptyState.noSearchResults();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFavorites.length,
      itemBuilder: (context, index) {
        final favorite = _filteredFavorites[index];
        return _buildFavoriteCard(favorite);
      },
    );
  }

  Widget _buildFavoriteList(FavoriteProvider provider, FavoriteType type) {
    final favorites = provider.getFavoritesByType(type);

    if (favorites.isEmpty) {
      return EmptyState(
        icon: _getTypeIcon(type),
        title: '暂无${_tabNames[type]}收藏',
        subtitle: _getEmptySubtitle(type),
      );
    }

    return LottieRefreshIndicator(
      onRefresh: () async {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.user != null) {
          await provider.loadFavorites(authProvider.user!.id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          return _buildFavoriteCard(favorite);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Favorite favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: FavoriteDisplay(
        favorite: favorite,
        onTap: () => _handleFavoriteTap(favorite),
        padding: const EdgeInsets.all(16),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getTypeIcon(favorite.type),
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDeleteConfirmDialog(favorite),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchController.clear();
        _filteredFavorites.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _handleFavoriteTap(Favorite favorite) {
    // TODO: 处理收藏项点击，如跳转到原消息或打开链接
    context.showSuccessToast('点击了收藏: ${favorite.title ?? 'Unknown'}');
  }

  void _showDeleteConfirmDialog(Favorite favorite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏'),
        content: Text('确定要删除来自 "${favorite.title ?? 'Unknown'}" 的收藏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => _deleteFavorite(favorite),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFavorite(Favorite favorite) async {
    Navigator.of(context).pop();

    final success = await context
        .read<FavoriteProvider>()
        .deleteFavorite(favorite.id, favorite.ownerId);

    if (mounted) {
      if (success) {
        context.showSuccessToast('收藏删除成功');
      } else {
        context.showErrorToast('删除收藏失败');
      }
    }
  }

  IconData _getTypeIcon(FavoriteType type) {
    switch (type) {
      case FavoriteType.message:
        return Icons.chat_bubble_outline;
      case FavoriteType.link:
        return Icons.link;
      case FavoriteType.text:
        return Icons.text_fields;
      default:
        return Icons.star;
    }
  }

  String _getEmptySubtitle(FavoriteType type) {
    switch (type) {
      case FavoriteType.message:
        return '长按聊天消息可以收藏';
      case FavoriteType.link:
        return '收藏的链接会显示在这里';
      case FavoriteType.text:
        return '收藏的文本会显示在这里';
      default:
        return '收藏的内容会显示在这里';
    }
  }
}
