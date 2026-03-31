import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' hide Icon; // Add Cupertino import
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/models/conversation.dart';
import '../../widgets/custom/conversation_item.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../widgets/custom/group_avatar.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/network_status_banner.dart';
import '../friends/friends_screen.dart';
import '../profile/profile_screen.dart';
// macOS window resizing is managed natively.
import '../subscriptions/subscriptions_home_screen.dart';
import 'package:linkme_flutter/features/hot/hot_screen.dart';
import '../community/community_notifications_screen.dart';
import '../academy/academy_home_screen.dart';
import '../../widgets/common/plus_menu_button.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../widgets/common/official_badge.dart';
import '../../widgets/common/gradient_icon.dart';
import '../../widgets/common/unread_badge.dart';
import '../../shared/providers/community_notification_provider.dart';
import '../../shared/providers/app_feature_provider.dart';
import '../../shared/providers/zennotes_invitation_provider.dart';
import '../../widgets/common/linkme_loader.dart';
import '../../shared/models/community_notification.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:lottie/lottie.dart';
import 'dart:math' as Math;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  // 好友页顶部搜索（承载在AppBar）
  final TextEditingController _friendSearchController = TextEditingController();
  final ValueNotifier<String> _friendSearchNotifier = ValueNotifier<String>('');
  final ValueNotifier<int> _friendsTabNotifier = ValueNotifier<int>(0);

  late List<TabItem> _tabs;
  AnimationController? _storeAnim; // 商城图标动画
  late bool _isMobileDevice;
  AppFeatureProvider? _featureProvider;

  // 控制 AppBar 透明度，实现下拉渐隐
  final ValueNotifier<double> _appBarOpacity = ValueNotifier(1.0);
  final ValueNotifier<double> _secondFloorDrag = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _isMobileDevice = !(defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        kIsWeb);
    if (_isMobileDevice) {
      _storeAnim = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3600))
        ..repeat();
    }
    _tabs = _buildDefaultTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 加载聊天数据并连接WebSocket（只初始化一次，避免重复加载导致数据重复）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();

      // Show one-time banner (e.g., banned reason) after routing lands on main screen
      final pending = authProvider.takePendingBanner();
      if (pending != null && mounted) {
        context.showErrorToast(pending);
      }

      if (authProvider.isLoggedIn &&
          authProvider.user != null &&
          authProvider.token != null) {
        try {
          await chatProvider.initializeIfNeeded(
              authProvider.user!.id, authProvider.token!);
        } catch (e) {
          print('❌ 初始化聊天失败: $e');
          // 若初始化失败，尽量显示已有会话
          await chatProvider.loadConversations();
        }
      } else {
        await chatProvider.loadConversations();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AppFeatureProvider>(context);
    if (_featureProvider == provider) return;
    _featureProvider?.removeListener(_handleFeatureUpdate);
    _featureProvider = provider;
    _featureProvider?.addListener(_handleFeatureUpdate);
    _applyFeatureConfig(provider);
  }

  void _handleFeatureUpdate() {
    if (!mounted || _featureProvider == null) return;
    _applyFeatureConfig(_featureProvider!);
  }

  void _applyFeatureConfig(AppFeatureProvider provider) {
    if (!_isMobileDevice) {
      _updateTabs(_buildDefaultTabs());
      return;
    }
    _updateTabs(_buildTabsFromProvider(provider));
  }

  List<TabItem> _buildDefaultTabs() {
    final tabs = <TabItem>[
      _chatTab(),
      _friendsTab(),
    ];
    if (_isMobileDevice) {
      tabs.add(_storeTab());
    }
    tabs.add(_academyTab());
    tabs.add(_profileTab());
    return tabs;
  }

  List<TabItem> _buildTabsFromProvider(AppFeatureProvider provider) {
    final tabs = <TabItem>[];
    if (provider.navMessageEnabled) tabs.add(_chatTab());
    if (provider.navFriendsEnabled) tabs.add(_friendsTab());
    if (_isMobileDevice && provider.navStoreEnabled) tabs.add(_storeTab());
    if (provider.navAcademyEnabled) tabs.add(_academyTab());
    if (provider.navProfileEnabled) tabs.add(_profileTab());
    if (tabs.isEmpty) {
      tabs.add(_chatTab());
      tabs.add(_profileTab());
    }
    return tabs;
  }

  void _updateTabs(List<TabItem> nextTabs) {
    if (_tabListsEqual(_tabs, nextTabs)) return;
    final targetIndex =
        nextTabs.isEmpty ? 0 : _currentIndex.clamp(0, nextTabs.length - 1);
    setState(() {
      _tabs = nextTabs;
    });
    _replaceTabController(nextTabs.length, targetIndex);
  }

  void _switchToTab(String tabId) {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1 || index >= _tabController.length) return;
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _tabController.animateTo(index);
  }

  void _replaceTabController(int length, int targetIndex) {
    if (length <= 0) return;
    final old = _tabController;
    _tabController = TabController(length: length, vsync: this);
    _tabController.addListener(_handleTabChange);
    final safeIndex = targetIndex.clamp(0, length - 1);
    _tabController.index = safeIndex;
    _currentIndex = safeIndex;
    old.dispose();
  }

  bool _tabListsEqual(List<TabItem> current, List<TabItem> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != next[i].id) return false;
    }
    return true;
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentIndex = _tabController.index;
    });
    HapticFeedback.lightImpact();
  }

  TabItem _chatTab() => TabItem(
        id: 'chat',
        featureKey: 'NAV_MESSAGE',
        icon: _isMobileDevice
            ? CupertinoIcons.chat_bubble_2
            : Icons.chat_bubble_outline,
        activeIcon: _isMobileDevice
            ? CupertinoIcons.chat_bubble_2_fill
            : Icons.chat_bubble,
        label: '聊天',
      );

  TabItem _friendsTab() => TabItem(
        id: 'friends',
        featureKey: 'NAV_FRIENDS',
        icon: _isMobileDevice ? CupertinoIcons.person_2 : Icons.people_outline,
        activeIcon:
            _isMobileDevice ? CupertinoIcons.person_2_fill : Icons.people,
        label: '好友',
      );

  TabItem _storeTab() => TabItem(
        id: 'store',
        featureKey: 'NAV_STORE',
        icon: _isMobileDevice ? CupertinoIcons.bag : Icons.storefront_outlined,
        activeIcon:
            _isMobileDevice ? CupertinoIcons.bag_fill : Icons.storefront,
        label: '商城',
      );

  TabItem _profileTab() => TabItem(
        id: 'profile',
        featureKey: 'NAV_PROFILE',
        icon: _isMobileDevice ? CupertinoIcons.person : Icons.person_outline,
        activeIcon: _isMobileDevice ? CupertinoIcons.person_fill : Icons.person,
        label: '我的',
      );

  TabItem _academyTab() => TabItem(
        id: 'academy',
        featureKey: 'NAV_ACADEMY',
        icon: _isMobileDevice ? CupertinoIcons.book : Icons.school_outlined,
        activeIcon: _isMobileDevice ? CupertinoIcons.book_fill : Icons.school,
        label: '学院',
      );

  Widget _buildTabContent(String id) {
    switch (id) {
      case 'chat':
        return _buildChatListPage();
      case 'friends':
        return _buildFriendsPage();
      case 'store':
        return _buildStorePlaceholderPage();
      case 'academy':
        return _buildAcademyPage();
      case 'profile':
        return _buildProfilePage();
      default:
        return _buildChatListPage();
    }
  }

  // 商城占位页（仅移动端展示）
  Widget _buildStorePlaceholderPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('商城')),
      body: const Center(
        child: Text('商城（示例数据，功能开发中）',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeAnim?.dispose();
    _friendSearchController.dispose();
    _friendSearchNotifier.dispose();
    _friendsTabNotifier.dispose();
    _featureProvider?.removeListener(_handleFeatureUpdate);
    _appBarOpacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildTabContent(tab.id)).toList(),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                onTap: (int index) {
                if (index >= _tabs.length) return;
                final tab = _tabs[index];
                if (tab.id == 'store') {
                  // 点击商城：跳转到独立商城页，并保持当前聊天Tab不变
                  final prev = _currentIndex;
                  // 立即恢复Tab选择（避免切换动画）
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tabController.animateTo(prev);
                  });
                  if (_isMobileDevice && mounted) {
                    context.push('/store');
                  }
                }
              },
              indicator: const BoxDecoration(),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              dividerColor: Colors.transparent, // 移除TabBar的分割线
              dividerHeight: 0, // 设置分割线高度为0
              labelStyle: AppTextStyles.navLabel.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.navLabel,
              tabs: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isActive = _currentIndex == index;
                // 商城Tab：自定义渐变文本 + 动画图标（点击后进入独立商城页）
                if (tab.id == 'store') {
                  return Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AnimatedStoreIcon(
                          controller: _storeAnim,
                          active: isActive,
                          icon: isActive ? tab.activeIcon : tab.icon,
                        ),
                        const SizedBox(height: 2),
                        _GradientNavText(
                          tab.label,
                          active: isActive,
                        ),
                      ],
                    ),
                  );
                }

                // 其他Tab：保持原有实现
                return Tab(
                  icon: Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      final unread =
                          tab.id == 'chat' ? chatProvider.totalUnreadCount : 0;
                      final iconWidget = AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          key: ValueKey(isActive),
                          size: 26, // 统一大小
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      );
                      if (unread <= 0) return iconWidget;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          iconWidget,
                          Positioned(
                            right: -10,
                            top: -4,
                            child: UnreadBadge(count: unread, minSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                  text: tab.label,
                );
              }).toList(),
            ),
          ),
        ),
        ),
      ),
        ),
      ),
    );
  }

  // 官方订阅号入口（聊天列表页顶部的小卡片）
  Widget _SubscriptionsEntry() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionsHomeScreen()),
        );
      },
      child: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Consumer<SubscriptionProvider>(
          builder: (context, sp, _) {
            // 首次进入时拉取订阅号列表
            sp.initialize();
            final subTitle =
                sp.channels.isNotEmpty ? sp.channels.first.name : '加载中...';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.campaign)),
              title: const Text('订阅号'),
              subtitle: Text(subTitle),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        ),
      ),
    );
  }

  // 聊天列表页面
  Widget _buildChatListPage() {
    return Scaffold(
      extendBodyBehindAppBar: true, // 允许body在AppBar后面，配合透明度变化
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _appBarOpacity,
          builder: (context, opacity, child) {
            // Opacity < 1.0 时，让 AppBar 背景变透明，同时内容变透明
            // 当完全透明时，不显示
            if (opacity <= 0.05) {
              return const SizedBox.shrink();
            }
            return Opacity(
              opacity: opacity,
              child: AppBar(
                backgroundColor: AppColors.primaryLight.withOpacity(opacity * 0.12), // 使用置顶背景色，并随下拉透明度变化
                elevation: 0, // 下拉时去掉阴影
                scrolledUnderElevation: 0,
                title: Consumer2<ChatProvider, AuthProvider>(
                  builder: (context, chatProvider, authProvider, _) {
                    final unreadCount = chatProvider.totalUnreadCount;
                    final user = authProvider.user;
                    return Row(
                      children: [
                        if (user != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: UserAvatar(
                              imageUrl: user.avatar,
                              name: user.nickname ?? user.username,
                              size: 32,
                              showOnlineStatus: true,
                              isOnline: true, // Current user is always online to themselves
                            ),
                          ),
                        if (unreadCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                        _isMobileDevice ? CupertinoIcons.search : Icons.search,
                        size: 24),
                    onPressed: () {
                      _showSearchPage();
                    },
                  ),
                  // 笔记按钮 - 胶囊渐变
                  Container(
                    height: 32,
                    margin: const EdgeInsets.only(right: 12, left: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF48FB1), // 粉色 (Pink 200/300 approx)
                          Color(0xFFCE93D8), // 紫色 (Purple 200/300 approx)
                        ],
                        // 尝试模拟 65% 粉色 : 35% 紫色的视觉重心
                        stops: [0.2, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF48FB1).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!mounted) return;
                          context.push('/notes');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isMobileDevice
                                    ? CupertinoIcons.pencil
                                    : Icons.edit,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '笔记',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 自定义加号菜单
                  PlusMenuButton(
                    items: [
                      PlusMenuItem(
                        icon: _isMobileDevice
                            ? CupertinoIcons.person_add
                            : Icons.person_add,
                        text: '添加好友',
                        onTap: () {
                          if (mounted) context.push('/add-friend');
                        },
                      ),
                      PlusMenuItem(
                        icon: _isMobileDevice
                            ? CupertinoIcons.person_3
                            : Icons.group_add,
                        text: '创建群聊',
                        onTap: () {
                          if (mounted) context.push('/create-group');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 占位，因为 extendBodyBehindAppBar: true，需要把内容顶下来
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),

              // 顶部状态提示条
              const NetworkStatusBanner(),
              // 列表主体
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    // 列表刷新优化：仅在首屏且为空时显示全屏加载；刷新时保留现有卡片
                    final isFirstLoading = chatProvider.isLoading &&
                        chatProvider.conversationList.isEmpty;
                    if (isFirstLoading) {
                      return const LoadingState(message: '加载聊天列表...');
                    }

                    final authProvider0 = context.read<AuthProvider>();
                    final communityProvider =
                        context.watch<CommunityNotificationProvider>();
                    if (!communityProvider.initialized) {
                      communityProvider.initialize(authProvider0);
                    }

                    // 计算置顶会话数量
                    final convs = chatProvider.conversationList;
                    final pinnedCount =
                        convs.takeWhile((c) => c.isPinned).length;
                    final showCommunity = communityProvider.shouldShowEntry;
                    // ZenNotes邀请卡片始终显示，不依赖社区通知
                    // 固定卡片数量：社区通知(可选) + ZenNotes邀请(始终) + 订阅号(始终)
                    final fixedCardCount = showCommunity ? 3 : 2;

                    return _FancyRefreshList(
                      onRefresh: () async {
                        final authProvider = context.read<AuthProvider>();
                        final userId = authProvider.user?.id;
                        await chatProvider.refreshConversations(userId);
                        await Future.delayed(const Duration(milliseconds: 150));
                      },
                      onEnterSecondFloor: () {
                        if (mounted) context.push('/hot');
                      },
                      // 监听拖拽更新，动态调整 AppBar 透明度
                      onDragUpdate: (dragDistance) {
                        // AppBar Opacity Logic
                        if (dragDistance > 0) {
                          double opacity =
                              (1.0 - (dragDistance / 25.0)).clamp(0.0, 1.0);
                          _appBarOpacity.value = opacity;
                        } else {
                          _appBarOpacity.value = 1.0;
                        }
                        // Update second floor preview visibility
                        _secondFloorDrag.value = dragDistance;
                      },
                      itemCount: convs.length + fixedCardCount,
                      itemBuilder: (context, index) {
                        // main_screen.dart | _MainScreenState | itemBuilder | 固定卡片显示逻辑
                        // 显示顺序：社区通知(可选) -> ZenNotes邀请 -> 订阅号
                        if (showCommunity) {
                          // 有社区通知时：社区通知 -> ZenNotes邀请 -> 订阅号
                          if (index == pinnedCount) {
                            return _buildCommunityNotifyListItem(context);
                          } else if (index == pinnedCount + 1) {
                            return _buildZenNotesInvitationListItem(context);
                          } else if (index == pinnedCount + 2) {
                            return _buildSubscriptionListItem(context);
                          }
                        } else {
                          // 无社区通知时：ZenNotes邀请 -> 订阅号
                          if (index == pinnedCount) {
                            return _buildZenNotesInvitationListItem(context);
                          } else if (index == pinnedCount + 1) {
                            return _buildSubscriptionListItem(context);
                          }
                        }
                        final offset = fixedCardCount;
                        final convIndex = index > pinnedCount + offset - 1
                            ? index - offset
                            : index;
                        if (convIndex >= convs.length) {
                          return const SizedBox.shrink();
                        }
                        final conversation = convs[convIndex];

                        return ConversationItemWithActions(
                          conversation: conversation,
                          onTap: () {
                            try {
                              chatProvider
                                  .markConversationAsRead(conversation.id);
                              if (mounted) {
                                final isGroup =
                                    conversation.type == ConversationType.group;
                                context.push(
                                    '/chat/${conversation.id}?type=${isGroup ? 'group' : 'private'}');
                              }
                            } catch (e) {
                              debugPrint('聊天跳转错误: $e');
                              if (mounted) {
                                context.showErrorToast('打开聊天失败，请重试');
                              }
                            }
                          },
                          onPin: () => chatProvider
                              .togglePinConversation(conversation.id),
                          onMute: () => chatProvider
                              .toggleMuteConversation(conversation.id),
                          onDelete: () =>
                              chatProvider.deleteConversation(conversation.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Second Floor Preview Overlay
          ValueListenableBuilder<double>(
            valueListenable: _secondFloorDrag,
            builder: (context, dragDistance, _) {
              const double secondFloorTrigger = 25.0;
              if (dragDistance < secondFloorTrigger) {
                return const SizedBox.shrink();
              }

              // Calculate the height from status bar bottom to the drag point
              final topPadding = MediaQuery.of(context).padding.top;
              final appBarHeight = kToolbarHeight;
              final totalTop = topPadding + appBarHeight;

              // Reserve space for hint text: 2px gap + 16px text + 2px gap = 20px
              const double hintTextArea = 20.0;
              final previewHeight = totalTop + dragDistance - hintTextArea;

              return Positioned(
                top: topPadding, // Start from below status bar
                left: 0,
                right: 0,
                height: previewHeight - topPadding, // Adjust height accordingly
                child: ClipPath(
                  clipper: _SecondFloorClipper(bottomArcHeight: 15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Real HotScreen Content
                      Transform.translate(
                        offset: Offset(0,
                            -topPadding), // Shift content up to show from top
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height,
                          child: const IgnorePointer(
                            child: HotScreen(),
                          ),
                        ),
                      ),
                      // Dark Overlay
                      Container(color: Colors.black.withOpacity(0.5)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 像会话一样的“订阅号”卡片，位于会话列表 index==0，随列表滚动
  Widget _buildSubscriptionListItem(BuildContext context) {
    return InkWell(
      onTap: () {
        context.showLoadingToast('加载中...');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionsHomeScreen()),
        );
        Future.delayed(const Duration(milliseconds: 350), Toast.hide);
      },
      child: Builder(
        builder: (context) {
          final sp = context.watch<SubscriptionProvider>();
          sp.initialize();
          final name =
              sp.channels.isNotEmpty ? sp.channels.first.name : '加载中...';
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(child: Icon(Icons.campaign)),
            title: const Text('订阅号',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(name),
            trailing: const OfficialBadge(size: 14),
          );
        },
      ),
    );
  }

  // “社区通知”卡片，和会话同级，位于置顶会话之后
  Widget _buildCommunityNotifyListItem(BuildContext context) {
    return Consumer<CommunityNotificationProvider>(
      builder: (context, cp, _) {
        // 延迟初始化，确保有用户信息
        final auth = context.read<AuthProvider>();
        if (!cp.initialized) cp.initialize(auth);
        final unread = cp.unreadCount;
        // 最新一条的简要内容： [文章/获赞/评论/回复] + 文章标题
        String subtitle;
        if (cp.items.isEmpty) {
          subtitle = '暂无新通知';
        } else {
          final n = cp.items.first;
          switch (n.type) {
            case CommunityNotificationType.publish:
              subtitle = '[文章] ${n.articleTitle}';
              break;
            case CommunityNotificationType.like:
              // 可按需隐藏点赞类型；这里保持最小描述
              final who = n.fromUserName ?? '用户';
              subtitle =
                  '[点赞] $who · ${n.likeTargetIsComment ? '你的评论' : '你的文章'}';
              break;
            case CommunityNotificationType.reply:
              final who = n.fromUserName ?? '用户';
              final content = (n.commentText ?? '').trim();
              final label = (n.isReply) ? '[回复]' : '[评论]';
              subtitle =
                  content.isNotEmpty ? '$label $who · $content' : '$label $who';
              break;
          }
        }
        // 自定义行样式，保持与会话项一致，并覆盖背景避免出现滑动背景透出
        return Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              // 打开即清空未读
              context.read<CommunityNotificationProvider>().markAllRead();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CommunityNotificationsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const CircleAvatar(
                      backgroundColor: Color(0xFFFFEDD5),
                      child: Icon(Icons.campaign, color: Color(0xFFFF7A00))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('社区通知',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  UnreadBadge(count: unread, color: const Color(0xFFFF7A00)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // main_screen.dart | _MainScreenState | _buildZenNotesInvitationListItem | context
  // "ZenNotes邀请"卡片，位于社区通知之后
  Widget _buildZenNotesInvitationListItem(BuildContext context) {
    return Consumer<ZenNotesInvitationProvider>(
      builder: (context, provider, _) {
        final unread = provider.unreadCount;
        // 最新一条邀请的简要内容
        String subtitle;
        if (provider.invitations.isEmpty) {
          subtitle = '暂无新邀请';
        } else {
          final invitation = provider.invitations.first;
          subtitle =
              '[邀请] ${invitation.inviterName} · ${invitation.notebookTitle}';
        }

        return Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              context.push('/zennotes-invitations');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE9F5FF),
                    child: Icon(Icons.note_add, color: Color(0xFF2B69FF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ZenNotes 邀请',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  UnreadBadge(count: unread, color: const Color(0xFF2B69FF)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 显示搜索页面
  void _showSearchPage() {
    showSearch(
      context: context,
      delegate: _ConversationSearchDelegate(),
    );
  }

  // 好友页面
  Widget _buildFriendsPage() {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Text('好友'),
            const SizedBox(width: 12),
            // 中间搜索框（5px圆角），位于“好友”右侧、“+”左侧
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _friendsTabNotifier,
                builder: (context, tabIndex, _) {
                  return SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _friendSearchController,
                      onChanged: (v) => _friendSearchNotifier.value = v,
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      style: AppTextStyles.input,
                      maxLines: 1,
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        hintText: tabIndex == 0 ? '搜索好友' : '搜索群聊',
                        prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 8, right: 4),
                            child: Icon(Icons.search,
                                size: 18, color: AppColors.textLight)),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        filled: false,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(
                              color: AppColors.borderLight, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          PlusMenuButton(
            items: [
              PlusMenuItem(
                icon: Icons.person_add,
                text: '添加好友',
                onTap: () {
                  context.push('/add-friend');
                },
              ),
            ],
          ),
        ],
      ),
      body: FriendsScreen(
        externalSearch: _friendSearchNotifier,
        segmentController: _friendsTabNotifier,
        showInternalSearch: false,
        onStartChat: () => _switchToTab('chat'),
      ),
    );
  }

  // 学院页面
  Widget _buildAcademyPage() {
    return const AcademyHomeScreen();
  }

  // 个人中心页面
  Widget _buildProfilePage() {
    return const ProfileScreen();
  }

  // Helper method to build hot card preview
  Widget _buildHotCardPreview() {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade300, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热榜',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
              3,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
        ],
      ),
    );
  }

  // Helper method to build category tab
  Widget _buildCategoryTab(String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFFFF3B30) : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: isActive ? 28 : 0,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

// --- Custom pull-to-refresh with "Link Me" gradient text ---
class _FancyRefreshList extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback? onEnterSecondFloor;
  final ValueChanged<double>? onDragUpdate;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  const _FancyRefreshList(
      {required this.onRefresh,
      this.onEnterSecondFloor,
      this.onDragUpdate,
      required this.itemCount,
      required this.itemBuilder});

  @override
  State<_FancyRefreshList> createState() => _FancyRefreshListState();
}

class _FancyRefreshListState extends State<_FancyRefreshList>
    with TickerProviderStateMixin {
  // Scale user's "px" requirements to logical pixels.
  // 0-60px -> Refresh Zone (Pull to refresh)
  // 60-120px -> Pre-Second Floor Zone (Release to refresh)
  // > 120px -> Second Floor Zone (Release to enter)
  static const double _refreshTrigger = 60.0;
  static const double _secondFloorTrigger = 120.0;
  static const double _maxDrag = 150.0;

  final ScrollController _controller = ScrollController();

  AnimationController? _headerController;
  double _drag = 0;
  bool _dragging = false;

  // Refresh States
  bool _refreshing = false;
  bool _refreshSuccess = false;

  bool get _atTop =>
      !_controller.hasClients || _controller.position.pixels <= 0;

  // Header height depends on state
  double get _headerHeight =>
      _refreshing ? _refreshTrigger : (_drag > 0 ? _drag : 0);

  @override
  void dispose() {
    _controller.dispose();
    _headerController?.dispose();
    super.dispose();
  }

  void _onNotif(ScrollNotification n) {
    if (!_atTop) return;

    if (n is ScrollStartNotification) {
      _dragging = true;
      _refreshSuccess = false; // Reset success state on new drag
    } else if (n is OverscrollNotification) {
      if (_dragging && n.overscroll < 0) {
        // Apply friction/damping
        double newDrag = _drag + (-n.overscroll * 0.6);
        if (newDrag > _maxDrag) newDrag = _maxDrag;
        setState(() => _drag = newDrag);
        widget.onDragUpdate?.call(_drag);
      }
    } else if (n is ScrollUpdateNotification) {
      if (_dragging && n.metrics.pixels <= 0 && (n.scrollDelta ?? 0) < 0) {
        double newDrag = _drag + (-(n.scrollDelta ?? 0) * 0.6);
        if (newDrag > _maxDrag) newDrag = _maxDrag;
        setState(() => _drag = newDrag);
        widget.onDragUpdate?.call(_drag);
      }
    } else if (n is ScrollEndNotification ||
        (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      if (_dragging) {
        _dragging = false;

        // Logic:
        // 1. If drag >= SecondFloorTrigger (120.0) -> Enter Second Floor
        // 2. If drag > 0 (Any pull) -> Refresh
        // 3. Else -> Reset

        if (widget.onEnterSecondFloor != null && _drag >= _secondFloorTrigger) {
          HapticFeedback.mediumImpact();
          widget.onEnterSecondFloor!();
          _animateHeader(0);
        } else if (_drag >= _refreshTrigger && !_refreshing) {
          // Trigger refresh only when dragged past the threshold
          _startRefresh();
        } else {
          _animateHeader(0);
        }
      }
    }
  }

  void _animateHeader(double target) {
    _headerController?.dispose();
    final controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _headerController = controller;
    final animation = Tween<double>(begin: _drag, end: target).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    animation.addListener(() {
      if (mounted) {
        setState(() => _drag = animation.value);
        widget.onDragUpdate?.call(_drag);
      }
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        if (identical(_headerController, controller)) {
          _headerController = null;
        }
      }
    });
    controller.forward();
  }

  Future<void> _startRefresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _refreshSuccess = false;
      _drag = _refreshTrigger; // Snap to refresh height (60.0)
    });
    widget.onDragUpdate?.call(_drag);

    HapticFeedback.lightImpact();

    try {
      await widget.onRefresh();
      if (mounted) {
        setState(() => _refreshSuccess = true);
        // Show success state for a moment
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _refreshSuccess = false;
        });
        _animateHeader(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _onNotif(n);
        return false;
      },
      child: CustomScrollView(
        controller: _controller,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
              child: SizedBox(
                  height: _headerHeight,
                  child: _FancyHeader(
                    dragDistance: _drag,
                    refreshTrigger: _refreshTrigger,
                    secondFloorTrigger: _secondFloorTrigger,
                    isRefreshing: _refreshing,
                    isSuccess: _refreshSuccess,
                  ))),
          SliverList(
              delegate: SliverChildBuilderDelegate(widget.itemBuilder,
                  childCount: widget.itemCount)),
        ],
      ),
    );
  }
}

class _FancyHeader extends StatelessWidget {
  final double dragDistance;
  final double refreshTrigger;
  final double secondFloorTrigger;
  final bool isRefreshing;
  final bool isSuccess;

  const _FancyHeader({
    required this.dragDistance,
    required this.refreshTrigger,
    required this.secondFloorTrigger,
    required this.isRefreshing,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    // Layout Constants
    const double textHeight = 20.0;
    const double gap = 2.0;

    // Determine State
    // 1. Second Floor Zone (>= 120.0)
    bool inSecondFloorZone = dragDistance >= secondFloorTrigger;

    Widget content;

    if (inSecondFloorZone) {
      // --- Second Floor State ---
      content = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(height: gap),
          SizedBox(
            height: textHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_upward_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Text(
                  '松手进入二楼',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
        ],
      );
    } else {
      // --- Refresh State ---

      String text;
      Widget icon;

      if (isSuccess) {
        text = '刷新成功';
        icon = const Icon(Icons.check_circle_outline,
            size: 16, color: AppColors.primary);
      } else if (isRefreshing) {
        text = '正在刷新';
        icon = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        );
      } else {
        if (dragDistance < refreshTrigger) {
          // 0-60px: Refresh Zone
          text = '松手刷新';
          icon = const Icon(Icons.arrow_downward_rounded,
              size: 16, color: AppColors.textSecondary);
        } else {
          // 60-120px: Pre-Second Floor Zone
          text = '继续下拉进入二楼';
          icon = const Icon(Icons.arrow_downward_rounded,
              size: 16, color: AppColors.textSecondary);
        }
      }

      content = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: textHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
        ],
      );
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.bottomCenter,
      child: content,
    );
  }
}

class _SemiCircleBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Rectangle top
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(
        size.width, size.height - 12); // End straight line before bottom

    // Convex Arc at bottom
    // "圆的底部圆弧就是与提示文本的间距为2px"
    // We create a gentle curve
    path.quadraticBezierTo(
      size.width / 2, size.height + 8, // Control point below
      0, size.height - 12, // End point
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class TabItem {
  final String id;
  final String featureKey;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const TabItem({
    required this.id,
    required this.featureKey,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// 渐变底部文字（浅粉 70% + 浅紫 30%）
class _GradientNavText extends StatelessWidget {
  final String text;
  final bool active;
  const _GradientNavText(this.text, {required this.active});

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF9EC1);
    const purple = Color(0xFFD0B3FF);
    final gradient = const LinearGradient(
      colors: [pink, purple],
      stops: [0.7, 1.0],
    );
    final style = AppTextStyles.navLabel.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white, // 被 ShaderMask 覆盖
      fontSize: active
          ? AppTextStyles.navLabel.fontSize! + 0.0
          : AppTextStyles.navLabel.fontSize,
    );
    final opacity = active ? 1.0 : 0.7;
    return Opacity(
      opacity: opacity,
      child: ShaderMask(
        shaderCallback: (Rect bounds) => gradient.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(text, style: style),
      ),
    );
  }
}

// 商城图标动画：先旋转 360°，再轻跳一下，循环，平缓连贯
// 在“跳起”阶段为图标增加自底向上的浅粉-浅紫渐变轮廓描边，不影响既有布局
class _AnimatedStoreIcon extends StatelessWidget {
  final AnimationController? controller;
  final bool active;
  final IconData icon;
  const _AnimatedStoreIcon(
      {required this.controller, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null) {
      return Icon(icon,
          size: 24, color: active ? AppColors.primary : AppColors.textLight);
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final t = ctrl.value; // 0..1
        // 旋转阶段：0..0.6 -> 0..360°
        final rotPhase = (t <= 0.6) ? (t / 0.6) : 1.0;
        final angle = rotPhase * 6.283185307179586; // 2π
        // 跳跃阶段：0.6..1.0 使用平滑正弦上抛下落
        double dy = 0.0;
        double jumpP = 0.0; // 跳起进度 0..1，用于控制轮廓描边的自底向上显现
        if (t > 0.6) {
          jumpP = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
          dy = -6.0 * Math.sin(3.141592653589793 * jumpP); // 轻跳幅度 6px
        }
        final color = active ? AppColors.primary : AppColors.textLight;

        // 基础填充图标（不变动），叠加一个只在跳起阶段出现的渐变描边层
        final baseIcon = Icon(icon, size: 24, color: color);
        final withOutline = Stack(
          alignment: Alignment.center,
          children: [
            baseIcon,
            if (jumpP > 0)
              // 只在跳起阶段显示描边，并且自底向上逐步显现
              _GradientStrokeIcon(
                icon: icon,
                size: 24,
                reveal: jumpP,
              ),
          ],
        );

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: angle, child: withOutline),
        );
      },
    );
  }
}

/// 渐变描边版本的 Icon：
/// - 使用 Text 绘制图标字形的描边（PaintingStyle.stroke），确保不改变现有布局
/// - 通过 ClipRect + Align(heightFactor) 实现描边从底部到顶部的显现
class _GradientStrokeIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double reveal; // 0..1，从底部到顶部的显现比例

  const _GradientStrokeIcon(
      {required this.icon, required this.size, required this.reveal});

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF9EC1); // 浅粉
    const purple = Color(0xFFD0B3FF); // 浅紫
    // 与底部文案一致的渐变配比，保持设计统一性
    const grad = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [pink, purple],
      stops: [0.7, 1.0],
    );

    // 使用文本字形绘制描边，避免 Icon 直接 stroke 不支持的问题
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white; // 实际颜色由 Shader 覆盖

    final glyph = Text(
      String.fromCharCode(icon.codePoint),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        package: icon.fontPackage,
        fontSize: size,
        height: 1.0, // 收敛行高，便于与 Icon 对齐
        foreground: strokePaint,
      ),
    );

    // 通过 ShaderMask 赋予描边渐变色，再用 ClipRect + Align 进行自底向上显现
    final gradientStroke = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) =>
          grad.createShader(Rect.fromLTWH(0, 0, size, size)),
      child: SizedBox(width: size, height: size, child: Center(child: glyph)),
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: reveal.clamp(0.0, 1.0),
          child: gradientStroke,
        ),
      ),
    );
  }
}

// 搜索委托
class _ConversationSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => '搜索聊天记录';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: '输入关键词搜索',
        subtitle: '搜索聊天记录、联系人',
      );
    }

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id;
    if (uid == null) {
      return const EmptyState(
          icon: Icons.error_outline, title: '未登录', subtitle: '请先登录');
    }

    return FutureBuilder(
      future: context
          .read<ChatProvider>()
          .searchMessages(userId: uid, query: query),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const EmptyState.noSearchResults();
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final chatProvider = context.read<ChatProvider>();
            final auth = context.read<AuthProvider>();
            final me = auth.user?.id;
            final conv = chatProvider.conversationList
                .where((c) => c.id == item.conversationId)
                .firstOrNull;

            Widget leading;
            if (item.isGroup) {
              leading = GroupAvatar(
                memberAvatars: conv?.participants
                        .map((u) => u.avatar ?? '')
                        .where((a) => a.isNotEmpty)
                        .toList() ??
                    const [],
                groupName: conv?.name ?? '群聊',
                size: 44,
                groupAvatar: conv?.avatar,
              );
            } else {
              final other = (conv?.participants ?? const [])
                  .where((u) => me == null || u.id != me)
                  .firstOrNull;
              leading = UserAvatar(
                imageUrl: other?.avatar ?? conv?.avatar,
                name: other?.nickname ?? other?.username ?? conv?.name,
                size: 44,
                showOnlineStatus: false,
                isOnline: false,
              );
            }

            return ListTile(
              leading: leading,
              title: Text(item.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: _highlightSnippet(context, item.snippet, query),
              onTap: () {
                close(context, item.conversationId);
                final type = item.isGroup ? 'group' : 'private';
                if (context.mounted)
                  context.push('/chat/${item.conversationId}?type=$type');
              },
            );
          },
        );
      },
    );
  }

  Widget _highlightSnippet(BuildContext context, String text, String kw) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(kw.toLowerCase());
    if (idx < 0)
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    final before = text.substring(0, idx);
    final mid = text.substring(idx, idx + kw.length);
    final after = text.substring(idx + kw.length);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: before, style: Theme.of(context).textTheme.bodyMedium),
          TextSpan(
              text: mid,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
          TextSpan(text: after, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SecondFloorClipper extends CustomClipper<Path> {
  final double bottomArcHeight;

  const _SecondFloorClipper({required this.bottomArcHeight});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Rectangle from top
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - bottomArcHeight);

    // Convex Arc at bottom
    path.quadraticBezierTo(
      size.width / 2, size.height + 8, // Control point below
      0, size.height - bottomArcHeight, // End point
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
