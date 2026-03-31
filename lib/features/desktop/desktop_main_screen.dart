import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'dart:ui' show ImageFilter; // for Gaussian blur
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/custom/user_avatar.dart';
import '../../widgets/common/network_status_banner.dart';
import '../../widgets/custom/conversation_item.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/user.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../chat/chat_detail_screen.dart';
import '../friends/friends_screen.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/services/auth_service.dart';
import '../legal/privacy_policy_screen.dart';
import '../subscriptions/subscriptions_home_screen.dart';
import '../subscriptions/channel_article_list_screen.dart';
import '../subscriptions/article_detail_screen.dart';
import '../../shared/providers/subscription_provider.dart';
import '../../widgets/common/official_badge.dart';
import '../../widgets/common/gradient_icon.dart';
import '../../core/desktop/window_control.dart';
import '../../shared/providers/policy_provider.dart';
import 'desktop_events.dart';

// A desktop-only home shell after login.
// Three panes: (1) slim nav rail, (2) conversation list with search, (3) chat pane.
// Keep color scheme light (white) and reuse existing widgets; no new features are introduced.
class DesktopMainScreen extends StatefulWidget {
  const DesktopMainScreen({super.key});

  static bool get isDesktopMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  State<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends State<DesktopMainScreen> {
  String? _selectedConversationId; // userId or groupId as string
  bool _selectedIsGroup = false;
  int _navIndex = 0; // 0: 聊天  1: 联系人
  _RightPaneMode _paneMode = _RightPaneMode.chat; // chat/subs*
  String? _subsChannelId;
  String? _subsArticleId;
  bool _isPaneLoading = false; // 右侧面板过渡加载

  final _searchController = TextEditingController();
  final ValueNotifier<String> _searchValue = ValueNotifier<String>('');
  final ValueNotifier<int> _contactsTabNotifier = ValueNotifier<int>(0);
  final GlobalKey _avatarKey = GlobalKey();
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    // Lazy init data like mobile main screen does
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();
      // Display one-shot banner if any (e.g., banned reason) on landing
      final pending = auth.takePendingBanner();
      if (pending != null && mounted) {
        context.showErrorToast(pending);
      }
      if (auth.isLoggedIn && auth.user != null && auth.token != null) {
        await chat.initializeIfNeeded(auth.user!.id, auth.token!);
      } else {
        await chat.loadConversations();
      }
      // Window resize behavior is controlled after successful login via AuthProvider.
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchValue.dispose();
    _contactsTabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only activate on macOS. If not, fallback to a placeholder to avoid accidental use.
    if (!DesktopMainScreen.isDesktopMacOS) {
      return const Scaffold(body: Center(child: Text('Desktop layout is macOS only')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Guard against ultra-small window before we toggle to desktop size
            final showThreePanes = constraints.maxWidth >= _kDesktopMinWidth;
            return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLeftRail(),
            _buildConversationPane(),
            if (showThreePanes) _buildChatPane() else Expanded(child: _buildSelectHint()),
          ],
            );
          },
        ),
      ),
    );
  }

  // Left slim vertical rail
  Widget _buildLeftRail() {
    return Container(
      width: 68,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 28), // space from macOS traffic lights
          // Link Me 文本 logo（确保不溢出）
          SizedBox(
            width: 56,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: _LinkMeLogo(),
            ),
          ),
          const SizedBox(height: 16),
          // Current user avatar (click to profile)
          Consumer<AuthProvider>(
            builder: (_, auth, __) {
              final u = auth.user;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  key: _avatarKey,
                  onTap: _showProfileCard,
                  child: UserAvatar(
                    imageUrl: u?.avatar,
                    name: u?.nickname ?? u?.username ?? '我',
                    size: 44,
                    showOnlineStatus: false,
                  ),
                ),
              );
            },
          ),
          // 功能图标：聊天 & 联系人
          _RailIcon(
            icon: Icons.chat_bubble,
            tooltip: '聊天',
            active: _navIndex == 0,
            onTap: () => setState(() => _navIndex = 0),
          ),
          _RailIcon(
            icon: Icons.person_outline,
            tooltip: '联系人',
            active: _navIndex == 1,
            onTap: () => setState(() => _navIndex = 1),
          ),
      // 收藏：打开独立窗口查看收藏
      _RailIcon(
        icon: Icons.bookmark_border,
        tooltip: '收藏',
        active: false,
        onTap: _openFavoritesWindow,
      ),
      // 热点：系统火焰图标，橙红渐变；按需求放在收藏下方
      _RailIcon(
        icon: Icons.local_fire_department,
        tooltip: '热点',
        active: false,
        gradient: AppColors.hotGradient,
        onTap: _openHotWindow,
      ),
          const Spacer(),
          _SettingsMenu(
            onItemSelected: (value) async {
              switch (value) {
                case 'privacy':
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(isTestingAgreement: false),
                    ),
                  );
                  break;
                case 'testing':
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(isTestingAgreement: true),
                    ),
                  );
                  break;
                case 'about':
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('关于LinkMe'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LinkMe v1.0.1'),
                          SizedBox(height: 8),
                          Text('一款简洁优雅的即时通讯应用'),
                          SizedBox(height: 8),
                          Text('© 2025 LinkMe Team'),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定')),
                      ],
                    ),
                  );
                  break;
                case 'logout':
                  if (!mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出当前账号吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('退出', style: TextStyle(color: AppColors.textWhite)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final auth = context.read<AuthProvider>();
                    await auth.logout();
                    if (!mounted) return;
                    context.showSuccessToast('已退出登录');
                    context.go('/login');
                  }
                  break;
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Middle conversations list with search
  Widget _buildConversationPane() {
    return Container(
      width: 320, // fixed list width similar to common IM desktop apps
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFEDEDED), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search + plus
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => _searchValue.value = v,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: _navIndex == 1 ? '搜索联系人/群聊' : '搜索会话',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PlusMenu(onSelected: (v) async {
                  if (!mounted) return;
                  // 桌面端（macOS）：两个入口都在新窗口中打开“添加好友”视图；
                  // 新窗口尺寸与登录窗口一致，且不可缩放。
                  if (DesktopMainScreen.isDesktopMacOS) {
                    if (v == 'add_friend') { await _openAddFriendWindow(); return; }
                    if (v == 'create_group') { await _openCreateGroupWindow(); return; }
                  }

                  // 其他平台维持原逻辑
                  if (v == 'add_friend') {
                    // ignore: use_build_context_synchronously
                    context.push('/add-friend');
                  } else if (v == 'create_group') {
                    // ignore: use_build_context_synchronously
                    context.push('/create-group');
                  }
                }),
              ],
            ),
          ),

          const NetworkStatusBanner(),

          Expanded(
            child: _navIndex == 1
                // 联系人模式：复用 FriendsScreen，外部搜索与分段标签由此控制
                ? FriendsScreen(
                    externalSearch: _searchValue,
                    segmentController: _contactsTabNotifier,
                    showInternalSearch: false,
                  )
                // 聊天模式：原有会话列表
                : Consumer<ChatProvider>(
                    builder: (context, chat, _) {
                      final list = chat.conversationList;
                      if (chat.isLoading && list.isEmpty) {
                        return const LoadingState(message: '加载聊天列表...');
                      }
                      // 即便没有任何会话，也展示订阅号入口

                      final q = _searchController.text.trim();
                      final filtered = q.isEmpty
                          ? list
                          : list.where((c) => c.displayName.toLowerCase().contains(q.toLowerCase())).toList();
                      final pinnedCount = filtered.takeWhile((c) => c.isPinned).length;

                      return ListView.builder(
                        // 在置顶会话之后插入“订阅号”卡片，随列表滚动
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == pinnedCount) {
                            return Consumer<SubscriptionProvider>(
                              builder: (context, sp, _) {
                                sp.initialize();
                                final name = sp.channels.isNotEmpty ? sp.channels.first.name : '加载中...';
                                return ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(child: Icon(Icons.campaign)),
                                  title: const Text('订阅号', style: TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(name),
                                  trailing: const OfficialBadge(size: 14),
                                  onTap: () {
                                    _transitionTo(_RightPaneMode.subsHome);
                                  },
                                );
                              },
                            );
                          }
                          final convIndex = index > pinnedCount ? index - 1 : index;
                          if (convIndex >= filtered.length) return const SizedBox.shrink();
                          final c = filtered[convIndex];
                          final selected = _selectedConversationId == c.id;
                          return ConversationItemWithActions(
                            conversation: c,
                            isSelected: selected,
                            onTap: () {
                              _transitionTo(_RightPaneMode.chat, convId: c.id, isGroup: c.type == ConversationType.group);
                              // 标记为已读
                              context.read<ChatProvider>().markConversationAsRead(c.id);
                            },
                            onPin: () => context.read<ChatProvider>().togglePinConversation(c.id),
                            onMute: () => context.read<ChatProvider>().toggleMuteConversation(c.id),
                            onDelete: () => context.read<ChatProvider>().deleteConversation(c.id),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Right chat pane (embed ChatDetailScreen or subscription views)
  Widget _buildChatPane() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // 内容
            Positioned.fill(child: _buildRightPaneContent()),
            // 过渡加载层
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isPaneLoading,
                child: AnimatedOpacity(
                  opacity: _isPaneLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    color: Colors.white.withOpacity(0.65),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 44,
                      height: 24,
                      child: Center(child: LinkMeLoader(fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPaneContent() {
    switch (_paneMode) {
      case _RightPaneMode.chat:
        if (_selectedConversationId == null) return const _EmptyChatPane();
        return NotificationListener<OpenArticleInPane>(
          onNotification: (evt) {
            _openArticleInPane(evt.channelId, evt.articleId);
            return true;
          },
          child: ChatDetailScreen(
            key: ValueKey('chat-${_selectedConversationId}'),
            contactId: _selectedConversationId!,
            isGroup: _selectedIsGroup,
          ),
        );
      case _RightPaneMode.subsHome:
        return SubscriptionsHomeView(onOpenChannel: (id) {
          _transitionTo(_RightPaneMode.subsChannel, channelId: id);
        });
      case _RightPaneMode.subsChannel:
        final id = _subsChannelId;
        if (id == null) return const _EmptyChatPane();
        return ChannelArticleListView(
          channelId: id,
          onOpenArticle: (aid) {
            _transitionTo(_RightPaneMode.subsArticle, channelId: id, articleId: aid);
          },
          onBack: () {
            _transitionTo(_RightPaneMode.subsHome);
          },
        );
      case _RightPaneMode.subsArticle:
        final id = _subsChannelId;
        final aid = _subsArticleId;
        if (id == null || aid == null) return const _EmptyChatPane();
        final article = context.read<SubscriptionProvider>().getArticle(id, aid);
        if (article == null) return const _EmptyChatPane();
        return ArticleDetailView.fromArticle(
          article,
          onBack: () => _transitionTo(_RightPaneMode.subsChannel, channelId: id),
          onShare: () => shareArticle(context, article),
        );
    }
  }

  // 桌面端：在第三栏打开订阅号文章
  Future<void> _openArticleInPane(String channelId, String articleId) async {
    setState(() { _isPaneLoading = true; });
    try {
      final sp = context.read<SubscriptionProvider>();
      await sp.ensureArticles(channelId);
      if (sp.getArticle(channelId, articleId) == null) {
        await sp.refreshArticles(channelId);
      }
      _transitionTo(_RightPaneMode.subsArticle, channelId: channelId, articleId: articleId);
    } catch (_) {
      _transitionTo(_RightPaneMode.subsArticle, channelId: channelId, articleId: articleId);
    } finally {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) setState(() { _isPaneLoading = false; });
      });
    }
  }

  // 右侧面板过渡：短暂显示加载动画，再切换内容
  void _transitionTo(_RightPaneMode mode, {String? channelId, String? articleId, String? convId, bool? isGroup}) {
    setState(() {
      _isPaneLoading = true;
    });
    // 先开启loading，稍后切换内容，再结束loading
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() {
        _paneMode = mode;
        if (convId != null) {
          _selectedConversationId = convId;
          _selectedIsGroup = isGroup ?? false;
        }
        if (channelId != null || mode == _RightPaneMode.subsHome) {
          _subsChannelId = channelId;
        }
        if (articleId != null || mode != _RightPaneMode.subsArticle) {
          _subsArticleId = articleId;
        }
      });
    });
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() {
        _isPaneLoading = false;
      });
    });
  }

  Widget _buildSelectHint() {
    return const Center(
      child: Text('窗口过窄，仅显示会话列表'),
    );
  }

  static const double _kDesktopMinWidth = 1040;
  static const double _kDesktopMinHeight = 720;

  // 打开收藏窗口：与登录窗口同尺寸，且不可拉伸。
  Future<void> _openFavoritesWindow() async {
    const MethodChannel channel = MethodChannel('window_control');
    try {
      await channel.invokeMethod('openWindow', {
        'route': '/favorites',
        'width': 420,
        'height': 620,
        'resizable': false,
      });
    } catch (e) {
      // 若原生失败，退化为当前窗口内打开
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.push('/favorites');
    }
  }

  // 打开热点窗口：要求与桌面主页同尺寸，且不可拉伸
  Future<void> _openHotWindow() async {
    const MethodChannel channel = MethodChannel('window_control');
    try {
      await channel.invokeMethod('openWindow', {
        'route': '/hot',
        'width': WindowControl.homeMinW,
        'height': WindowControl.homeMinH,
        'resizable': false,
      });
    } catch (e) {
      // 兜底：当前窗口内打开
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.push('/hot');
    }
  }

  // 打开“添加好友”窗口：与登录窗口同尺寸，且不可拉伸。
  Future<void> _openAddFriendWindow() async {
    const MethodChannel channel = MethodChannel('window_control');
    try {
      await channel.invokeMethod('openWindow', {
        'route': '/add-friend',
        'width': 420,
        'height': 620,
        'resizable': false,
      });
    } catch (e) {
      // 若原生失败，退化为当前窗口内打开
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.push('/add-friend');
    }
  }

  // 打开“创建群聊”窗口：与登录窗口同尺寸，且不可拉伸。
  Future<void> _openCreateGroupWindow() async {
    const MethodChannel channel = MethodChannel('window_control');
    try {
      await channel.invokeMethod('openWindow', {
        'route': '/create-group',
        'width': 420,
        'height': 620,
        'resizable': false,
      });
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.push('/create-group');
    }
  }
  // 显示头像右侧的个人信息卡片（尺寸随内容自适应，r=9，毛玻璃 + 半透明 + 细灰边）。
  void _showProfileCard() {
    final ctx = _avatarKey.currentContext;
    if (ctx == null) return;
    final RenderBox box = ctx.findRenderObject() as RenderBox;
    final Offset tl = box.localToGlobal(Offset.zero);
    final Size szz = box.size;

    final Size screen = MediaQuery.of(context).size;
    // 右侧 3px 间距；顶部与头像顶部对齐；高度自适应，做一个保守的边界
    final double left = (tl.dx + szz.width + 3).clamp(0.0, screen.width - 240);
    final double top = tl.dy.clamp(12.0, screen.height - 260);

    // 内部状态：编辑态与控制器（在 builder 外声明，避免重建时被重置）
    bool editingSig = false;
    final TextEditingController sigController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'profile_card',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 90),
      pageBuilder: (_, __, ___) {
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: _FrostCard(
              child: StatefulBuilder(builder: (context, setInner) {

                return Consumer<AuthProvider>(builder: (_, auth, __) {
                  final u = auth.user;
                  final name = u?.nickname ?? u?.username ?? '';
                  final username = u?.username ?? '';
                  final email = u?.email ?? '';
                  final phone = u?.phone ?? '';
                  final status = u?.status;
                  final currentSig = u?.signature ?? '';
                  if (!editingSig && sigController.text.isEmpty) sigController.text = currentSig;

                  String statusText = '离线';
                  Color statusColor = AppColors.offline;
                  switch (status) {
                    case UserStatus.online:
                    case UserStatus.active:
                      statusText = '在线';
                      statusColor = AppColors.online;
                      break;
                    case UserStatus.away:
                      statusText = '离开';
                      statusColor = AppColors.warning;
                      break;
                    case UserStatus.busy:
                      statusText = '忙碌';
                      statusColor = AppColors.error;
                      break;
                    case UserStatus.offline:
                    case null:
                      statusText = '离线';
                      statusColor = AppColors.offline;
                      break;
                  }

                  Widget kv(IconData icon, String label, String value) {
                    if (value.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: AppTextStyles.overline.copyWith(color: AppColors.textLight)),
                                const SizedBox(height: 2),
                                Text(value, style: AppTextStyles.body2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Future<void> saveSignature(String newSig) async {
                    final auth = context.read<AuthProvider>();
                    final usr = auth.user;
                    if (usr != null) auth.setUser(usr.copyWith(signature: newSig));
                    setInner(() { editingSig = false; });
                    final resp = await AuthService().updateProfile(signature: newSig.isEmpty ? null : newSig);
                    if (resp.isSuccess && resp.data != null) {
                      auth.setUser(resp.data!);
                      if (context.mounted) context.showSuccessToast('签名已更新');
                    } else {
                      if (context.mounted) context.showErrorToast(resp.message ?? '更新失败');
                    }
                  }

                  return Container(
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题 + 在线状态
                        Row(
                          children: [
                            Expanded(child: Text(name, style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(statusText, style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        kv(Icons.badge_outlined, '用户名', username),
                        kv(Icons.mail_outline, '邮箱', email),
                        kv(Icons.phone_iphone, '手机', phone),

                        // 签名（行内编辑）
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.edit_note_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('签名', style: AppTextStyles.overline.copyWith(color: AppColors.textLight)),
                                    const SizedBox(height: 2),
                                    if (!editingSig) Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(currentSig.isEmpty ? '未设置' : currentSig, style: AppTextStyles.body2),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(4),
                                          onTap: () {
                                            sigController.text = currentSig;
                                            setInner(() { editingSig = true; });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Icon(Icons.edit_outlined, size: 14, color: AppColors.textLight),
                                          ),
                                        ),
                                      ],
                                    ) else Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: sigController,
                                            maxLines: 3,
                                            minLines: 1,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                              hintText: '输入你的个性签名...',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => saveSignature(sigController.text.trim()),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.check_circle, size: 18, color: AppColors.online),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        InkWell(
                                          onTap: () => setInner(() { editingSig = false; }),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.cancel, size: 18, color: AppColors.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                });
              }),
            ),
          ),
        ]);
      },
    ).then((_) => sigController.dispose());
  }




}

enum _RightPaneMode {
  chat,
  subsHome,
  subsChannel,
  subsArticle,
}

class _RailIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final Gradient? gradient; // 可选的渐变填充（用于“热点”图标）
  const _RailIcon({required this.icon, required this.tooltip, required this.active, required this.onTap, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: gradient == null
              ? Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 22)
              : GradientIcon(icon: icon, size: 22, gradient: gradient!),
        ),
      ),
    );
  }
}

class _LinkMeLogo extends StatefulWidget {
  const _LinkMeLogo();

  @override
  State<_LinkMeLogo> createState() => _LinkMeLogoState();
}

class _LinkMeLogoState extends State<_LinkMeLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ani;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 每次扫过的时间
    );
    _ani = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1)); // 起始停留
      await _ctrl.forward(from: 0);
      await Future.delayed(const Duration(seconds: 2)); // 与上面合计 3s 周期
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseText = Text(
      'Link Me',
      textAlign: TextAlign.center,
      style: AppTextStyles.h6.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        // 英文字体回退
        fontFamily: 'Helvetica Neue',
        fontFamilyFallback: const ['SF Pro Text', 'Avenir Next', 'Arial'],
        color: AppColors.primary, // 粉色主体
        letterSpacing: 0.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.visible,
    );

    return AnimatedBuilder(
      animation: _ani,
      builder: (context, child) {
        // 构造一条从左到右移动的高亮
        final double p = _ani.value; // 0..1
        final Gradient g = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.transparent,
          ],
          stops: [
            (p - 0.10).clamp(0.0, 1.0),
            p.clamp(0.0, 1.0),
            (p + 0.10).clamp(0.0, 1.0),
          ],
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            // 底层粉色文字
            baseText,
            // 顶层白色高亮遮罩（随动画扫过）
            ShaderMask(
              shaderCallback: (rect) => g.createShader(rect),
              blendMode: BlendMode.srcATop,
              child: baseText,
            ),
          ],
        );
      },
    );
  }
}

class _PlusMenu extends StatefulWidget {
  final void Function(String value) onSelected;
  const _PlusMenu({required this.onSelected});

  @override
  State<_PlusMenu> createState() => _PlusMenuState();
}

class _PlusMenuState extends State<_PlusMenu> {
  final GlobalKey _iconKey = GlobalKey();

  void _showMenu() {
    // 计算加号图标的全局位置
    final renderBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
    final Offset topLeft = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final double left = topLeft.dx; // 左侧与图标左侧对齐
    final double top = topLeft.dy + size.height + 6; // 显示在下方

    const double menuWidth = 127; // 比聊天右键菜单窄 5px（132-5）

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'plus_menu',
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
                    BoxShadow(color: AppColors.shadowMedium, blurRadius: 10, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuItem(
                      icon: Icons.add_circle_outline,
                      label: '创建群聊',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelected('create_group');
                      },
                    ),
                    _menuItem(
                      icon: Icons.person_add_alt,
                      label: '加好友/群',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelected('add_friend');
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

  Widget _menuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0x1F000000),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _iconKey,
      icon: const Icon(Icons.add_circle_outline),
      onPressed: _showMenu,
      tooltip: '新建/添加',
    );
  }
}

class _EmptyChatPane extends StatelessWidget {
  const _EmptyChatPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textLight),
          SizedBox(height: 12),
          Text('选择左侧会话开始聊天', style: AppTextStyles.body2),
        ],
      ),
    );
  }
}


// 左侧栏底部的设置按钮与菜单
class _SettingsMenu extends StatefulWidget {
  final void Function(String value) onItemSelected;
  const _SettingsMenu({required this.onItemSelected});

  @override
  State<_SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
  final GlobalKey _iconKey = GlobalKey();

  void _showMenu() {
    final renderBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
    final Offset topLeft = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // 定位：菜单显示在设置图标“正上方”，左侧与图标左侧对齐，间距 3px。
    const double menuWidth = 132; // 与聊天页右键菜单一致
    const double itemHeight = 34; // 单项近似高度（图标+内边距），用于粗略估计整体高度
    const double vPadding = 12; // 容器上下内边距之和（6+6）
    // 这里的菜单项数量需要跟下面 children 中的项目保持一致
    final policy = context.read<PolicyProvider>();
    final bool showPrivacy = policy.enabled('PRIVACY');
    final bool showTesting = policy.enabled('TESTING');
    final int itemCount = (showPrivacy ? 1 : 0) + (showTesting ? 1 : 0) + 2; // 关于 + 退出 必有
    final double menuHeight = itemCount * itemHeight + vPadding;
    final double screenH = MediaQuery.of(context).size.height;

    final double left = topLeft.dx; // 与图标左侧完全对齐
    double top = topLeft.dy - menuHeight - 3; // 图标上方 3px 间距
    // 边界约束，避免超出屏幕
    if (top < 12) top = 12;
    if (top + menuHeight > screenH - 12) top = screenH - menuHeight - 12;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'settings_menu',
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
                    BoxShadow(color: AppColors.shadowMedium, blurRadius: 10, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPrivacy)
                      _menuItem(icon: Icons.privacy_tip_outlined, label: '隐私政策', onTap: () {
                        Navigator.of(context).pop();
                        widget.onItemSelected('privacy');
                      }),
                    if (showTesting)
                      _menuItem(icon: Icons.rule_folder_outlined, label: '测试协议', onTap: () {
                        Navigator.of(context).pop();
                        widget.onItemSelected('testing');
                      }),
                    _menuItem(icon: Icons.info_outline, label: '关于LinkMe', onTap: () {
                      Navigator.of(context).pop();
                      widget.onItemSelected('about');
                    }),
                    // 新增：退出登录（仅桌面端设置菜单）
                    _menuItem(icon: Icons.logout, label: '退出登录', onTap: () {
                      Navigator.of(context).pop();
                      widget.onItemSelected('logout');
                    }),
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _menuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0x1F000000),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _iconKey,
      icon: const Icon(Icons.settings_outlined),
      onPressed: _showMenu,
      tooltip: '设置',
    );
  }
}


class _FrostCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  const _FrostCard({this.width, this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72), // 轻微透明
            border: Border.all(color: const Color(0x1F000000)), // 细灰边
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowLight, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          // Provide a Material ancestor for InkWell ripple/gestures
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}

// 编辑签名按钮：点击弹出输入框并保存到后端与本地
class _EditSignatureButton extends StatelessWidget {
  final String initial;
  final ValueChanged<String> onSaved;
  const _EditSignatureButton({required this.initial, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final controller = TextEditingController(text: initial);
        final newSig = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('修改签名'),
              content: SizedBox(
                width: 360,
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: '输入你的个性签名...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('保存')),
              ],
            );
          },
        );

        if (newSig == null) return;

        // 立即本地更新，提升响应
        onSaved(newSig);

        // 后端保存
        final auth = context.read<AuthProvider>();
        final api = AuthService();
        final resp = await api.updateProfile(signature: newSig.isEmpty ? null : newSig);
        if (resp.isSuccess && resp.data != null) {
          auth.setUser(resp.data!);
          if (context.mounted) context.showSuccessToast('签名已更新');
        } else {
          if (context.mounted) context.showErrorToast(resp.message ?? '更新失败');
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.edit_outlined, size: 14, color: AppColors.textLight),
      ),
    );
  }
}
