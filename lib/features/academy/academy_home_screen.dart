import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/custom_toast.dart';
import '../../core/widgets/image_viewer.dart';
import '../../core/widgets/video_preview_widget.dart';
import '../../core/widgets/video_player_widget.dart';
import '../../shared/providers/auth_provider.dart';
import 'academy_search_screen.dart';
import 'academy_profile_screen.dart';
import 'create_post/create_post_screen.dart';
import 'post_detail/post_detail_screen.dart';
import 'services/academy_api.dart';

/// academy_home_screen.dart | AcademyHomeScreen | 学院主页
class AcademyHomeScreen extends StatefulWidget {
  const AcademyHomeScreen({super.key});

  @override
  State<AcademyHomeScreen> createState() => _AcademyHomeScreenState();
}

class _AcademyHomeScreenState extends State<AcademyHomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _categoryTabController;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _courseScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _showSearchBar = true;
  bool _showBackToTop = false;
  bool _showCourseBackToTop = false;
  double _lastScrollOffset = 0;
  bool _isExpanded = false;

  // 下拉刷新状态
  bool _isRefreshing = false;
  bool _refreshSuccess = false;
  double _refreshOffset = 0;

  // 课程下拉刷新状态
  bool _isCourseRefreshing = false;
  bool _courseRefreshSuccess = false;
  double _courseRefreshOffset = 0;

  // 课程相关状态
  int _selectedCourseCategory = 0;
  int _selectedSubCategory = 0;
  bool _courseCategoryPinned = false;

  final List<String> _fixedCategories = ['推荐', '热门', '课程']; // 固定的3个tab
  List<String> _dynamicCategories = []; // 从后台动态加载的分类
  List<String> _allCategories = []; // 所有分类 = 固定 + 动态

  // 帖子列表数据
  List<Map<String, dynamic>> _recommendPosts = [];
  List<Map<String, dynamic>> _hotPosts = [];
  Map<String, List<Map<String, dynamic>>> _categoryPosts = {}; // 动态分类的帖子
  bool _isLoadingPosts = false;
  Map<String, int> _currentPageMap = {}; // 每个分类独立的页码
  Map<String, bool> _hasMorePostsMap = {}; // 每个分类独立的更多数据状态

  // 课程大分类 - 从后端动态加载
  // 课程大分类 - 固定3个
  final List<Map<String, dynamic>> _courseCategories = [
    {
      'name': '前端开发',
      'icon': 'assets/app_icons/svg/code.svg',
      'selectedColors': [Color(0xFFFF6B9D), Color(0xFFC06FFF)],
      'unselectedColors': [Color(0xFFFFE0EB), Color(0xFFF0E0FF)],
    },
    {
      'name': '后端开发',
      'icon': 'assets/app_icons/svg/computing.svg',
      'selectedColors': [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      'unselectedColors': [Color(0xFFE0F4FF), Color(0xFFE0FCFF)],
    },
    {
      'name': '移动开发',
      'icon': 'assets/app_icons/svg/mobile-programming.svg',
      'selectedColors': [Color(0xFFFFB75E), Color(0xFFED8F03)],
      'unselectedColors': [Color(0xFFFFF3E0), Color(0xFFFFE8CC)],
    },
  ];

  final List<String> _subCategories = [
    '全部',
    'Flutter',
    'React',
    'Vue',
    'Angular'
  ];

  Map<String, bool> _isEmptyMap = {}; // 每个分类的空状态
  bool _isError = false; // 是否加载失败

  @override
  void initState() {
    super.initState();
    print('🚀 [Academy Home] initState 开始');
    _allCategories = List.from(_fixedCategories); // 初始化为固定分类
    _categoryTabController = TabController(
      length: _allCategories.length,
      vsync: this,
    );
    _categoryTabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _courseScrollController.addListener(_onCourseScroll);
    print('📝 [Academy Home] 准备加载分类和推荐帖子');
    _loadCategories(); // 加载动态分类
    _loadPosts('recommend');

    // 进入学院页面时，自动同步用户资料到学院系统
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserProfile();
    });

    print('✅ [Academy Home] initState 完成');
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _syncUserProfile | 同步APP用户资料到学院
  Future<void> _syncUserProfile() async {
    try {
      final auth = context.read<AuthProvider>();
      // 确保用户已登录且有资料
      if (auth.user != null) {
        print('🔄 [Academy Home] 正在同步用户资料: ${auth.user!.nickname}');
        await AcademyApi.syncUserProfile(
          nickname: auth.user!.nickname,
          avatar: auth.user!.avatar,
        );
        print('✅ [Academy Home] 用户资料同步成功');
      }
    } catch (e) {
      // 同步失败不影响主流程，仅打印日志
      print('⚠️ [Academy Home] 用户资料同步失败 (非阻断性): $e');
    }
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _loadCategories | 加载动态分类
  Future<void> _loadCategories() async {
    try {
      final categories = await AcademyApi.getPostCategories();
      if (mounted && categories.isNotEmpty) {
        setState(() {
          _dynamicCategories = categories;
          _allCategories = [..._fixedCategories, ...categories];
          // 重新创建TabController
          _categoryTabController.dispose();
          _categoryTabController = TabController(
            length: _allCategories.length,
            vsync: this,
          );
          _categoryTabController.addListener(_onTabChanged);
        });
        print('✅ [Academy Home] 加载到${categories.length}个动态分类: $categories');
      }
    } catch (e) {
      print('❌ [Academy Home] 加载分类失败: $e');
    }
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _onTabChanged | 监听Tab切换
  void _onTabChanged() {
    if (!_categoryTabController.indexIsChanging) return;

    final currentCategory = _allCategories[_categoryTabController.index];
    if (currentCategory == '推荐') {
      if (_recommendPosts.isEmpty && !_isLoadingPosts) {
        _loadPosts('recommend');
      }
    } else if (currentCategory == '热门') {
      if (_hotPosts.isEmpty && !_isLoadingPosts) {
        _loadPosts('hot');
      }
    } else if (currentCategory != '课程') {
      // 动态分类
      if (!_categoryPosts.containsKey(currentCategory) ||
          _categoryPosts[currentCategory]!.isEmpty) {
        _loadPosts(currentCategory);
      }
    }
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    _scrollController.dispose();
    _courseScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    // 增加滚动阈值，减少敏感度
    if (delta > 8 && currentOffset > 80) {
      if (_showSearchBar) setState(() => _showSearchBar = false);
    } else if (delta < -8) {
      if (!_showSearchBar) setState(() => _showSearchBar = true);
    }

    if (currentOffset > 400) {
      if (!_showBackToTop) setState(() => _showBackToTop = true);
    } else {
      if (_showBackToTop) setState(() => _showBackToTop = false);
    }

    _lastScrollOffset = currentOffset;
  }

  void _onCourseScroll() {
    final currentOffset = _courseScrollController.offset;

    if (currentOffset > 120) {
      if (!_courseCategoryPinned) setState(() => _courseCategoryPinned = true);
    } else {
      if (_courseCategoryPinned) setState(() => _courseCategoryPinned = false);
    }

    if (currentOffset > 400) {
      if (!_showCourseBackToTop) setState(() => _showCourseBackToTop = true);
    } else {
      if (_showCourseBackToTop) setState(() => _showCourseBackToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    HapticFeedback.lightImpact();
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _openSearchPage | 打开搜索页面
  /// 从底部弹出搜索页面，支持iOS和Android的差异化动画
  void _openSearchPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AcademySearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // iOS和Android使用不同的动画效果
          if (Platform.isIOS) {
            // iOS: 从底部滑入
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          } else {
            // Android: 从底部滑入 + 淡入
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var slideTween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: curve),
            );
            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          }
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        fullscreenDialog: true,
      ),
    );
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _openCreatePostPage | 打开发帖页面
  /// 从底部弹出发帖页面，支持iOS和Android的差异化动画
  void _openCreatePostPage() async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreatePostScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (Platform.isIOS) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          } else {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var slideTween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: curve),
            );
            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          }
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        fullscreenDialog: true,
      ),
    );

    // 发布成功后刷新当前分类的帖子列表
    if (result == true && mounted) {
      print('✅ [Academy Home] 发布成功，刷新帖子列表');
      final currentCategory = _allCategories[_categoryTabController.index];
      String type;
      if (currentCategory == '推荐') {
        type = 'recommend';
      } else if (currentCategory == '热门') {
        type = 'hot';
      } else if (currentCategory == '课程') {
        return; // 课程分类不需要刷新帖子
      } else {
        type = currentCategory; // 动态分类
      }
      await _loadPosts(type, refresh: true);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                    height: MediaQuery.of(context).padding.top,
                    color: Colors.white),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _showSearchBar ? 60 : 0,
                  child: _showSearchBar ? _buildSearchBar() : const SizedBox(),
                ),
                _buildCategoryTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _categoryTabController,
                    children: _allCategories.map((category) {
                      if (category == '课程') {
                        return _buildCourseContent();
                      } else {
                        return _buildPostContent(category);
                      }
                    }).toList(),
                  ),
                ),
              ],
            ),
            if (_showBackToTop && !_isExpanded)
              Positioned(right: 16, bottom: 80, child: _buildBackToTopButton()),
            Positioned(
                right: 3, bottom: 2, child: _buildFloatingActionButtons()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 搜索框 - 点击打开搜索页面
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _openSearchPage();
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset(
                        'assets/app_icons/svg/search-normal.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Color(0xFF999999), BlendMode.srcIn),
                      ),
                    ),
                    const Text(
                      '搜索课程、帖子...',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 发帖按钮
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _openCreatePostPage();
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF0F5), Color(0xFFFFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE4EC), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/app_icons/svg/edit.svg',
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF555555), BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '发帖',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类Tab - 左边距16与搜索框对齐
  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      height: 48,
      alignment: Alignment.bottomLeft,
      child: TabBar(
        controller: _categoryTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.only(left: 16),
        indicatorPadding: EdgeInsets.zero,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 3, color: AppColors.primary),
          insets: EdgeInsets.zero,
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: const Color(0xFF666666),
        labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        labelPadding: const EdgeInsets.only(right: 24),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        tabs: _allCategories.map((c) => Tab(text: c)).toList(),
      ),
    );
  }

  /// 帖子内容 - 自定义下拉刷新
  Widget _buildPostContent(String category) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 下拉过程中更新偏移量
          if (_scrollController.position.pixels < 0 && !_isRefreshing) {
            setState(() {
              _refreshOffset = -_scrollController.position.pixels;
            });
          }
        } else if (notification is ScrollEndNotification) {
          // 松手时判断是否触发刷新
          if (_refreshOffset > 60 && !_isRefreshing) {
            _startRefresh();
          } else {
            setState(() => _refreshOffset = 0);
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 下拉刷新指示器 - 跟随下拉位置显示
          SliverToBoxAdapter(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: (_refreshOffset > 0 || _isRefreshing || _refreshSuccess)
                  ? 50
                  : 0,
              color: const Color(0xFFF6F7FB),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_refreshSuccess)
                    SvgPicture.asset(
                      'assets/app_icons/svg/tick-circle.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          AppColors.primary, BlendMode.srcIn),
                    )
                  else if (_isRefreshing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  else
                    SvgPicture.asset(
                      'assets/app_icons/svg/arrow-down.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF666666), BlendMode.srcIn),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _refreshSuccess
                        ? '刷新成功'
                        : (_isRefreshing
                            ? '正在刷新'
                            : (_refreshOffset > 60 ? '松手刷新' : '下拉刷新')),
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
          // 帖子列表
          // 帖子列表 content logic
          if (_getCurrentPosts(category).isEmpty)
            // 列表为空时的三种状态：错误、空数据、加载中
            if (_isError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/app_icons/svg/danger.svg',
                          width: 48,
                          height: 48,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFFCCCCCC), BlendMode.srcIn)),
                      const SizedBox(height: 16),
                      const Text('服务器错误，请稍后重试',
                          style: TextStyle(
                              color: Color(0xFF999999), fontSize: 14)),
                    ],
                  ),
                ),
              )
            else if (_isEmptyMap[_getCategoryType(category)] == true)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/app_icons/svg/document.svg',
                          width: 48,
                          height: 48,
                          colorFilter: const ColorFilter.mode(
                              Color(0xFFCCCCCC), BlendMode.srcIn)),
                      const SizedBox(height: 16),
                      const Text('当前没有帖子',
                          style: TextStyle(
                              color: Color(0xFF999999), fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              // 初始加载中
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
          else
            // 有数据，显示列表
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final posts = _getCurrentPosts(category);
                  if (index < posts.length) {
                    return _buildPostCard(posts[index]);
                  }
                  // 底部加载更多指示器：仅当有更多数据、未在刷新且正在加载更多时显示
                  // 防止下拉刷新时底部也出现Loading造成跳动
                  else if ((_hasMorePostsMap[_getCategoryType(category)] ??
                          true) &&
                      !_isRefreshing &&
                      !_isError) {
                    if (_isLoadingPosts) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    } else {
                      // 预加载：滚动到底部自动触发
                      // 使用 Future.microtask 避免在 build 中直接 setState
                      Future.microtask(() {
                        String type;
                        if (category == '推荐') {
                          type = 'recommend';
                        } else if (category == '热门') {
                          type = 'hot';
                        } else {
                          type = category; // 动态分类
                        }
                        _loadPosts(type);
                      });
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    }
                  }
                  return null;
                },
                childCount: _getCurrentPosts(category).length + 1,
              ),
            )
        ],
      ),
    );
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _loadPosts | type | 加载帖子列表
  Future<void> _loadPosts(String type, {bool refresh = false}) async {
    print('📥 [Academy Home] _loadPosts 被调用: type=$type, refresh=$refresh');

    if (_isLoadingPosts) {
      print('⏸️ [Academy Home] 已经在加载中，跳过');
      return;
    }

    setState(() => _isLoadingPosts = true);
    print('🔄 [Academy Home] 开始加载帖子...');

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;
      print('👤 [Academy Home] 当前用户ID: $userId');

      final page = refresh ? 0 : (_currentPageMap[type] ?? 0);
      print('📄 [Academy Home] 请求页码: $page (type=$type)');

      final result = await AcademyApi.getPosts(
        type: type,
        page: page,
        size: 10,
        userId: userId,
      ).timeout(const Duration(seconds: 15));

      print('📦 [Academy Home] 收到结果: ${result.runtimeType}');
      print('📦 [Academy Home] 结果keys: ${result.keys}');

      if (mounted) {
        final List<dynamic> content = result['content'] ?? [];
        print('📝 [Academy Home] content数量: ${content.length}');
        final posts = content.map((e) => e as Map<String, dynamic>).toList();
        print('✅ [Academy Home] 解析后帖子数量: ${posts.length}');
        if (posts.isNotEmpty) {
          print('📦 [Academy Home] 第一个帖子数据: ${posts.first}');
          print('📦 [Academy Home] images字段: ${posts.first['images']}');
          print('📦 [Academy Home] videoUrl字段: ${posts.first['videoUrl']}');
          print(
              '📦 [Academy Home] videoUrl是否存在: ${posts.first.containsKey('videoUrl')}');
          print(
              '📦 [Academy Home] 作者信息: authorName=${posts.first['authorName']}, authorAvatar=${posts.first['authorAvatar']}, authorLevel=${posts.first['authorLevel']}');
        }

        setState(() {
          if (refresh) {
            if (type == 'recommend') {
              _recommendPosts = posts;
            } else if (type == 'hot') {
              _hotPosts = posts;
            } else {
              // 动态分类
              _categoryPosts[type] = posts;
            }
            _currentPageMap[type] = 0; // 重置该分类页码
            _isEmptyMap[type] = posts.isEmpty;
          } else {
            if (type == 'recommend') {
              _recommendPosts.addAll(posts);
            } else if (type == 'hot') {
              _hotPosts.addAll(posts);
            } else {
              // 动态分类
              if (!_categoryPosts.containsKey(type)) {
                _categoryPosts[type] = [];
              }
              _categoryPosts[type]!.addAll(posts);
            }
          }

          // 始终更新空状态
          final currentPosts = type == 'recommend'
              ? _recommendPosts
              : (type == 'hot' ? _hotPosts : (_categoryPosts[type] ?? []));
          _isEmptyMap[type] = currentPosts.isEmpty;

          _currentPageMap[type] = (page ?? 0) + 1; // 更新该分类页码
          _hasMorePostsMap[type] = !(result['last'] ?? true); // 更新该分类是否还有更多
          _isError = false;
        });

        print(
            '📊 [Academy Home] 状态更新: type=$type, isEmpty=${_isEmptyMap[type]}, hasMore=${_hasMorePostsMap[type]}, nextPage=${_currentPageMap[type]}');
      }
    } catch (e) {
      print('❌ [Academy Home] 加载帖子列表失败: $e');
      print('❌ [Academy Home] 异常类型: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          // 超时或加载失败时，设置为空状态而非持续加载
          _isEmptyMap[type] = true;
          _isError = false; // 不显示错误状态，直接显示空
          print('❌ [Academy Home] 设置 _isEmptyMap[$type] = true');
        });
        // 仅当不是TimeoutException时显示SnackBar
        if (e is! TimeoutException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载失败: ${e.toString()}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshOffset = 0;
    });

    final currentCategory = _allCategories[_categoryTabController.index];
    if (currentCategory != '课程') {
      String type;
      if (currentCategory == '推荐') {
        type = 'recommend';
      } else if (currentCategory == '热门') {
        type = 'hot';
      } else {
        // 动态分类，直接使用分类名称
        type = currentCategory;
      }
      await _loadPosts(type, refresh: true);
    }

    if (mounted) {
      if (_isError) {
        setState(() {
          _isRefreshing = false;
          _refreshSuccess = false;
        });
      } else {
        setState(() {
          _isRefreshing = false;
          _refreshSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          setState(() => _refreshSuccess = false);
        }
      }
    }
  }

  /// 帖子卡片 - 区分长文和打卡
  Widget _buildPostCard(Map<String, dynamic> post) {
    final isArticle =
        post['title'] != null && (post['title'] as String).isNotEmpty;

    print('🎴 [PostCard] 构建帖子卡片 - id: ${post['id']}, isArticle: $isArticle');
    print('🎴 [PostCard] videoUrl: ${post['videoUrl']}');
    print('🎴 [PostCard] images: ${post['images']}');

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: post['id'] as int,
              isArticle: isArticle,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isArticle) ...[
              // 长文模式：左文右图
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _removeImageMarkers(post['contentPreview'] ?? ''),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF666666)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 按顺序显示第一个媒体（图片或视频）
                  if (_getFirstMediaWidget(post) != null) ...[
                    const SizedBox(width: 12),
                    _getFirstMediaWidget(post)!,
                  ] else if (post['images'] != null &&
                      (post['images'] as List).isNotEmpty) ...[
                    const SizedBox(width: 12),
                    // 长文主图 (1张)
                    GestureDetector(
                      onTap: () {
                        final images = post['images'] as List;
                        ImageViewer.show(
                          context,
                          imageUrls: images.map((e) => e.toString()).toList(),
                          initialIndex: 0,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          (post['images'] as List).first.toString(),
                          width: 100,
                          height: 75,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 100,
                              height: 75,
                              color: const Color(0xFFF5F5F5),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                '❌ [PostCard] 图片加载失败: $error, URL: ${(post['images'] as List).first}');
                            return _buildPlaceholderImage(100, 75);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              // 打卡模式：上文下多图
              RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF333333), height: 1.5),
                  children: [
                    TextSpan(
                        text:
                            _removeImageMarkers(post['contentPreview'] ?? '')),
                    const TextSpan(
                      text: ' 全文',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // 显示媒体（视频+图片混合，最多3个）
              if ((post['videoUrl'] != null &&
                      (post['videoUrl'] as String).isNotEmpty) ||
                  (post['images'] != null &&
                      (post['images'] as List).isNotEmpty)) ...[
                const SizedBox(height: 12),
                _buildMediaRow(post),
              ],
            ],

            const SizedBox(height: 12),
            // 用户信息
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: post['authorAvatar'] != null
                      ? NetworkImage(post['authorAvatar'])
                      : null,
                  child: post['authorAvatar'] == null
                      ? SvgPicture.asset(
                          'assets/app_icons/svg/user.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                              AppColors.primary, BlendMode.srcIn),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(post['authorName'] ?? '用户',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333))),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Lv.${post['authorLevel'] ?? 1}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.w600)),
                ),
                if (post['isVip'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('VIP',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                Text(_formatTime(post['createdAt']),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
            ),
            if (post['latestComment'] != null) ...[
              const SizedBox(height: 12),
              // 最新评论
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/app_icons/svg/message.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF999999), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            if (post['latestCommentUserName'] != null) ...[
                              TextSpan(
                                text: '${post['latestCommentUserName']}：',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF333333),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            TextSpan(
                              text: post['latestComment'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 底部操作栏
            Row(
              children: [
                if (post['topics'] != null &&
                    (post['topics'] as List).isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('#${(post['topics'] as List).first}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                  ),
                const Spacer(),
                _buildActionButton('assets/app_icons/svg/heart.svg',
                    '${post['likeCount'] ?? 0}'),
                const SizedBox(width: 16),
                _buildActionButton('assets/app_icons/svg/message.svg',
                    '${post['commentCount'] ?? 0}'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showMoreOptions(context, post),
                  child: SvgPicture.asset(
                    'assets/app_icons/svg/more.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF999999), BlendMode.srcIn),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _getCurrentPosts | category | 获取当前分类的帖子列表
  List<Map<String, dynamic>> _getCurrentPosts(String category) {
    if (category == '推荐') {
      return _recommendPosts;
    } else if (category == '热门') {
      return _hotPosts;
    } else {
      return _categoryPosts[category] ?? [];
    }
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _getCategoryType | category | 获取分类对应的type
  String _getCategoryType(String category) {
    if (category == '推荐') {
      return 'recommend';
    } else if (category == '热门') {
      return 'hot';
    } else {
      return category; // 动态分类直接使用分类名
    }
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _formatTime | 格式化时间
  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final DateTime time = DateTime.parse(createdAt.toString());
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}小时前';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return '${time.month}-${time.day}';
      }
    } catch (e) {
      return '';
    }
  }

  void _showMoreOptions(BuildContext context, Map<String, dynamic> post) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final postAuthorId = post['authorId'];
    final isOwnPost = currentUserId == postAuthorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost) ...[
              // 自己的帖子：显示编辑和删除选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/edit.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('编辑帖子'),
                onTap: () {
                  Navigator.pop(context);
                  _editPostFromList(post);
                },
              ),
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/trash.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFFF3B30),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text(
                  '删除帖子',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePostFromList(post);
                },
              ),
            ] else ...[
              // 别人的帖子：显示屏蔽和举报选项
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/close-circle.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('屏蔽用户'),
                onTap: () {
                  Navigator.pop(context);
                  CustomToast.showWarning(context, '开发中');
                },
              ),
              ListTile(
                leading: SvgPicture.asset(
                  'assets/app_icons/svg/danger.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(context);
                  CustomToast.showWarning(context, '开发中');
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 从列表中编辑帖子
  Future<void> _editPostFromList(Map<String, dynamic> post) async {
    // 先获取完整的帖子详情
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      final postDetail = await AcademyApi.getPostDetail(
        post['id'] as int,
        userId: userId,
      );

      if (mounted) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CreatePostScreen(
              postId: post['id'] as int,
              postData: postDetail,
            ),
          ),
        );

        // 编辑成功后刷新列表
        if (result == true && mounted) {
          final currentCategory = _allCategories[_categoryTabController.index];
          String type;
          if (currentCategory == '推荐') {
            type = 'recommend';
          } else if (currentCategory == '热门') {
            type = 'hot';
          } else {
            type = currentCategory;
          }
          await _loadPosts(type, refresh: true);
        }
      }
    } catch (e) {
      print('获取帖子详情失败: $e');
      if (mounted) {
        CustomToast.showError(context, '加载失败');
      }
    }
  }

  /// 从列表中删除帖子
  Future<void> _deletePostFromList(Map<String, dynamic> post) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId == null) {
      CustomToast.showWarning(context, '请先登录');
      return;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确定要删除这篇帖子吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AcademyApi.deletePost(post['id'] as int, userId);
      if (mounted) {
        // 从当前列表中移除该帖子
        setState(() {
          final currentCategory = _allCategories[_categoryTabController.index];
          if (currentCategory == '推荐') {
            _recommendPosts.removeWhere((p) => p['id'] == post['id']);
          } else if (currentCategory == '热门') {
            _hotPosts.removeWhere((p) => p['id'] == post['id']);
          } else if (_categoryPosts.containsKey(currentCategory)) {
            _categoryPosts[currentCategory]!
                .removeWhere((p) => p['id'] == post['id']);
          }
        });
        CustomToast.showSuccess(context, '删除成功');
      }
    } catch (e) {
      print('删除帖子失败: $e');
      if (mounted) {
        CustomToast.showError(context, '删除失败');
      }
    }
  }

  Widget _buildActionButton(String iconPath, String count) {
    return Row(
      children: [
        SvgPicture.asset(iconPath,
            width: 18,
            height: 18,
            colorFilter:
                const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn)),
        const SizedBox(width: 4),
        Text(count,
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
      ],
    );
  }

  /// 移除内容中的图片和视频标记
  String _removeImageMarkers(String content) {
    return content
        .replaceAll(RegExp(r'\[img:\d+\]'), '')
        .replaceAll(RegExp(r'\[video:\d+\]'), '')
        .trim();
  }

  /// 构建媒体行（视频+图片混合，最多3个）
  Widget _buildMediaRow(Map<String, dynamic> post) {
    final List<Widget> mediaWidgets = [];
    final videoUrl = post['videoUrl'];
    final images = post['images'] as List?;

    // 添加视频（如果有）
    if (videoUrl != null && (videoUrl as String).isNotEmpty) {
      mediaWidgets.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullScreenVideoPlayer(
                    videoUrl: videoUrl,
                    thumbnailUrl: post['videoThumbnail']?.toString(),
                  ),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 视频缩略图或黑色背景
                    if (post['videoThumbnail'] != null &&
                        (post['videoThumbnail'] as String).isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post['videoThumbnail'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.black),
                        ),
                      ),
                    // 播放图标（使用SVG，无外圈）
                    SvgPicture.asset(
                      'assets/app_icons/svg/play.svg',
                      width: 48,
                      height: 48,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 添加图片（最多3个，包括视频）
    if (images != null && images.isNotEmpty) {
      final remainingSlots = 3 - mediaWidgets.length;
      final imagesToShow = images.length > remainingSlots
          ? images.sublist(0, remainingSlots)
          : images;

      for (int i = 0; i < imagesToShow.length; i++) {
        mediaWidgets.add(
          Expanded(
            child: GestureDetector(
              onTap: () {
                ImageViewer.show(
                  context,
                  imageUrls: images.map((e) => e.toString()).toList(),
                  initialIndex: i,
                );
              },
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imagesToShow[i].toString(),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ [PostCard] 图片加载失败: $error');
                      return _buildPlaceholderImage(
                          double.infinity, double.infinity);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 在媒体之间添加间距
    final List<Widget> rowChildren = [];
    for (int i = 0; i < mediaWidgets.length; i++) {
      rowChildren.add(mediaWidgets[i]);
      if (i < mediaWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return Row(children: rowChildren);
  }

  /// 获取长文模式的第一个媒体（按内容顺序）
  Widget? _getFirstMediaWidget(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    final videoUrl = post['videoUrl'];
    final images = post['images'] as List?;
    final videoThumbnail = post['videoThumbnail']; // 视频缩略图URL

    // 如果内容中有标记，按标记顺序
    final RegExp mediaPattern = RegExp(r'\[(img|video):(\d+)\]');
    final match = mediaPattern.firstMatch(content);

    if (match != null) {
      final mediaType = match.group(1); // 'img' 或 'video'
      final mediaIndex = int.tryParse(match.group(2) ?? '');

      if (mediaType == 'video' &&
          videoUrl != null &&
          (videoUrl as String).isNotEmpty) {
        // 显示视频缩略图
        return _buildVideoThumbnail(videoUrl, videoThumbnail, 100, 75);
      } else if (mediaType == 'img' &&
          mediaIndex != null &&
          images != null &&
          mediaIndex < images.length) {
        // 显示图片
        return _buildImageThumbnail(images[mediaIndex].toString(), 100, 75);
      }
    }

    // 如果没有标记，优先显示图片（如果有）
    if (images != null && images.isNotEmpty) {
      return _buildImageThumbnail(images.first.toString(), 100, 75);
    }

    // 最后显示视频
    if (videoUrl != null && (videoUrl as String).isNotEmpty) {
      return _buildVideoThumbnail(videoUrl, videoThumbnail, 100, 75);
    }

    return null;
  }

  /// 构建视频缩略图
  Widget _buildVideoThumbnail(
      String videoUrl, dynamic thumbnailUrl, double width, double height) {
    return VideoPreviewWidget(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl != null ? thumbnailUrl.toString() : null,
      width: width,
      height: height,
      aspectRatio: 16 / 9,
    );
  }

  /// 构建图片缩略图
  Widget _buildImageThumbnail(String imageUrl, double width, double height) {
    return GestureDetector(
      onTap: () {
        ImageViewer.show(
          context,
          imageUrls: [imageUrl],
          initialIndex: 0,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFF5F5F5),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ [PostCard] 图片加载失败: $error, URL: $imageUrl');
            return _buildPlaceholderImage(width, height);
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.image, color: Color(0xFFCCCCCC)),
    );
  }

  Widget _buildCourseContent() {
    return Stack(
      children: [
        // 灰色背景层（用于下拉刷新区域）
        Container(color: const Color(0xFFF6F7FB)),
        Column(
          children: [
            // 大分类卡片（白色背景，固定）
            _buildCourseCategoryCards(),
            // 小分类（白色背景，固定）
            _buildSubCategoryChips(),
            // 下拉刷新指示器（灰色背景区域）
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: (_courseRefreshOffset > 0 ||
                      _isCourseRefreshing ||
                      _courseRefreshSuccess)
                  ? 50
                  : 0,
              color: const Color(0xFFF6F7FB),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_courseRefreshSuccess)
                    SvgPicture.asset('assets/app_icons/svg/tick-circle.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                            AppColors.primary, BlendMode.srcIn))
                  else if (_isCourseRefreshing)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary)))
                  else
                    SvgPicture.asset('assets/app_icons/svg/arrow-down.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                            Color(0xFF666666), BlendMode.srcIn)),
                  const SizedBox(width: 8),
                  Text(
                    _courseRefreshSuccess
                        ? '刷新成功'
                        : (_isCourseRefreshing
                            ? '正在刷新'
                            : (_courseRefreshOffset > 60 ? '松手刷新' : '下拉刷新')),
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            // 课程列表
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    if (_courseScrollController.position.pixels < 0 &&
                        !_isCourseRefreshing) {
                      setState(() => _courseRefreshOffset =
                          -_courseScrollController.position.pixels);
                    }
                  } else if (notification is ScrollEndNotification) {
                    if (_courseRefreshOffset > 60 && !_isCourseRefreshing) {
                      _startCourseRefresh();
                    } else {
                      setState(() => _courseRefreshOffset = 0);
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _courseScrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.zero,
                  itemCount: 10,
                  itemBuilder: (context, index) => _buildCourseCard(index),
                ),
              ),
            ),
          ],
        ),
        if (_showCourseBackToTop)
          Positioned(
              right: 16,
              bottom: 80,
              child: _buildBackToTopButton(isCourse: true)),
      ],
    );
  }

  Future<void> _startCourseRefresh() async {
    setState(() {
      _isCourseRefreshing = true;
      _courseRefreshOffset = 0;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isCourseRefreshing = false;
        _courseRefreshSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _courseRefreshSuccess = false);
    }
  }

  /// 课程大分类卡片 - 每个卡片始终有自己的渐变背景色
  Widget _buildCourseCategoryCards() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _courseCategoryPinned ? 56 : 140,
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: _courseCategoryPinned ? 6 : 12),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          const spacing = 10.0;
          final totalSpacing = spacing * (_courseCategories.length - 1);
          final availableWidth = totalWidth - totalSpacing;
          const totalParts = 4.0;
          final selectedWidth = (availableWidth / totalParts) * 2;
          final unselectedWidth = availableWidth / totalParts;

          return Row(
            children: List.generate(_courseCategories.length, (index) {
              final isSelected = _selectedCourseCategory == index;
              final category = _courseCategories[index];
              final colors = isSelected
                  ? category['selectedColors'] as List<Color>
                  : category['unselectedColors'] as List<Color>;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCourseCategory = index);
                  HapticFeedback.lightImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? selectedWidth : unselectedWidth,
                  margin: EdgeInsets.only(
                      right:
                          index < _courseCategories.length - 1 ? spacing : 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(_courseCategoryPinned ? 8 : 16),
                  ),
                  child: _courseCategoryPinned
                      ? _buildPinnedCategoryContent(category, isSelected)
                      : _buildExpandedCategoryContent(category, isSelected),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPinnedCategoryContent(
      Map<String, dynamic> category, bool isSelected) {
    final iconColor = isSelected ? Colors.white : const Color(0xFF666666);
    final textColor = isSelected ? Colors.white : const Color(0xFF666666);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              category['icon'] as String,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                category['name'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCategoryContent(
      Map<String, dynamic> category, bool isSelected) {
    final iconColor = isSelected ? Colors.white : const Color(0xFF666666);
    final textColor = isSelected ? Colors.white : const Color(0xFF666666);

    return Stack(
      children: [
        if (isSelected) ...[
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
            ),
          ),
        ],
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                category['icon'] as String,
                width: isSelected ? 40 : 28,
                height: isSelected ? 40 : 28,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  category['name'] as String,
                  style: TextStyle(
                    fontSize: isSelected ? 15 : 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryChips() {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _subCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedSubCategory == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSubCategory = index);
              HapticFeedback.lightImpact();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  _subCategories[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/app_icons/svg/video-play.svg',
                width: 36,
                height: 36,
                colorFilter:
                    const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flutter 完整开发教程',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Text(
                  '从零开始学习Flutter，掌握跨平台移动应用开发技能',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('¥99',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B6B))),
                    const SizedBox(width: 8),
                    if (index % 3 == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('会员免费',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToTopButton({bool isCourse = false}) {
    return GestureDetector(
      onTap: () {
        if (isCourse) {
          _courseScrollController.animateTo(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut);
        } else {
          _scrollToTop();
        }
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/app_icons/svg/arrow-up.svg',
            width: 20,
            height: 20,
            colorFilter:
                const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    final functionButtons = [
      {
        'icon': 'assets/app_icons/svg/user-octagon.svg',
        'label': '个人中心',
        'gradient': [Color(0xFFF3E5F5), Color(0xFFE1BEE7)]
      },
      {
        'icon': 'assets/app_icons/svg/archive-book.svg',
        'label': '收藏',
        'gradient': [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]
      },
      {
        'icon': 'assets/app_icons/svg/messages.svg',
        'label': '收到的评论',
        'gradient': [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]
      },
      {
        'icon': 'assets/app_icons/svg/heart.svg',
        'label': '收到的赞',
        'gradient': [Color(0xFFFCE4EC), Color(0xFFF8BBD9)]
      },
      {
        'icon': 'assets/app_icons/svg/teacher.svg',
        'label': '学习中',
        'gradient': [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]
      },
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 功能按钮列表
        if (_isExpanded)
          SizedBox(
            width: MediaQuery.of(context).size.width - 100,
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.only(right: 8, left: 16),
              children: functionButtons.map((btn) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _buildFunctionButton(
                    btn['icon'] as String,
                    btn['label'] as String,
                    btn['gradient'] as List<Color>,
                  ),
                );
              }).toList(),
            ),
          ),
        // 展开/收起按钮
        GestureDetector(
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isExpanded
                    ? [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)]
                    : [
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.primary
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _isExpanded
                      ? const Color(0x10000000)
                      : AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: SvgPicture.asset(
                    'assets/app_icons/svg/arrow-left.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      _isExpanded ? const Color(0xFF666666) : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isExpanded ? '收起更多' : '展开更多',
                  style: TextStyle(
                    color: _isExpanded ? const Color(0xFF666666) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// academy_home_screen.dart | _AcademyHomeScreenState | _onFunctionButtonTap | 功能按钮点击事件
  /// @param label 按钮标签，用于区分不同功能
  void _onFunctionButtonTap(String label) {
    HapticFeedback.lightImpact();
    switch (label) {
      case '个人中心':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AcademyProfileScreen(),
          ),
        );
        break;
      case '收藏':
        // TODO: 跳转收藏页面
        break;
      case '收到的评论':
        // TODO: 跳转评论页面
        break;
      case '收到的赞':
        // TODO: 跳转点赞页面
        break;
      case '学习中':
        // TODO: 跳转学习中页面
        break;
    }
  }

  Widget _buildFunctionButton(String icon, String label, List<Color> gradient) {
    return GestureDetector(
      onTap: () => _onFunctionButtonTap(label),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(icon,
                width: 16,
                height: 16,
                colorFilter:
                    const ColorFilter.mode(Color(0xFF555555), BlendMode.srcIn)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
