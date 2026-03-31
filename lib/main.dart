import 'dart:async';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'widgets/common/linkme_loader.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';
import 'shared/providers/quick_link_provider.dart';
import 'shared/providers/favorite_provider.dart';
import 'shared/providers/pinned_message_provider.dart';
import 'shared/providers/wallet_provider.dart';
import 'shared/providers/subscription_provider.dart';
import 'shared/providers/policy_provider.dart';
import 'shared/providers/community_notification_provider.dart';
import 'shared/providers/app_feature_provider.dart';
import 'shared/providers/zennotes_invitation_provider.dart';
import 'shared/providers/call_provider.dart';
import 'widgets/call/incoming_call_dialog.dart';
import 'core/utils/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/network/network_manager.dart';

import 'features/notes/providers/notes_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置强制竖屏
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化网络层
  ApiClient().initialize();
  NetworkManager().initialize();

  runApp(const LinkMeApp());
}

class LinkMeApp extends StatefulWidget {
  const LinkMeApp({super.key});

  @override
  State<LinkMeApp> createState() => _LinkMeAppState();
}

class _LinkMeAppState extends State<LinkMeApp> with WidgetsBindingObserver {
  late AuthProvider _authProvider;
  late ChatProvider _chatProvider;
  late QuickLinkProvider _quickLinkProvider;
  late FavoriteProvider _favoriteProvider;
  late PinnedMessageProvider _pinnedMessageProvider;
  late WalletProvider _walletProvider;
  late SubscriptionProvider _subscriptionProvider;
  late PolicyProvider _policyProvider;
  late CommunityNotificationProvider _communityProvider;
  late AppFeatureProvider _appFeatureProvider;
  late NotesProvider _notesProvider;
  late ZenNotesInvitationProvider _zenNotesInvitationProvider;
  late CallProvider _callProvider;
  late final VoidCallback _authStateListener;
  bool _routerRefreshScheduled = false;
  // 将 GoRouter 缓存为状态，避免因 Provider 的通知而重复创建导致路由回到初始页面
  late GoRouter _router;
  String? _pendingRoute; // 用于多窗口场景下在路由重建时保留目标页
  bool _showSplash = true;
  Timer? _splashTimer;
  DateTime? _lastForegroundTime;
  static const Duration _splashInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _chatProvider = ChatProvider();
    _quickLinkProvider = QuickLinkProvider();
    _favoriteProvider = FavoriteProvider();
    _pinnedMessageProvider = PinnedMessageProvider();
    _walletProvider = WalletProvider();
    _subscriptionProvider = SubscriptionProvider();
    _policyProvider = PolicyProvider();
    _communityProvider = CommunityNotificationProvider();
    _appFeatureProvider = AppFeatureProvider();
    _notesProvider = NotesProvider();
    _zenNotesInvitationProvider = ZenNotesInvitationProvider();
    _callProvider = CallProvider();
    _appFeatureProvider.attachAuthProvider(_authProvider);

    // 建立Provider之间的连接
    _authProvider.setChatProvider(_chatProvider);
    _authProvider.setNotesProvider(_notesProvider);
    _authProvider.setZenNotesInvitationProvider(_zenNotesInvitationProvider);

    // 设置API客户端的Token过期回调
    ApiClient().onTokenExpired = () {
      print('🔄 Token过期，自动登出...');
      _authProvider.logout();
    };

    // 初始化AuthProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider.initialize();
      _policyProvider.initialize();
      _communityProvider.initialize(_authProvider);
      _appFeatureProvider.initialize();
      _callProvider.init();
      _callProvider.setChatProvider(_chatProvider);
      
      // main.dart | _LinkMeAppState | initState | 设置通话回调
      // 作用：设置来电回调和通话结束刷新聊天消息回调
      _callProvider.onIncomingCall = _handleIncomingCall;
      _callProvider.onCallEndedNeedRefreshChat = (conversationId, isGroup, result, duration, callType) {
        // 通话结束后，ChatDetailScreen 会通过 upsertLocalMessage 本地插入消息
        // 这里不再调用 getChatMessages，因为服务器可能还没有生成通话记录
        // 避免覆盖本地的 optimistic update
        debugPrint('[main] 通话结束: $conversationId, result=$result, duration=$duration');
      };
    });

    // 初始化路由，只在认证状态变化时重建路由实例
    _router = AppRouter.createRouter(_authProvider);
    _authStateListener = _handleAuthStateChanged;
    _authProvider.authStateListenable.addListener(_authStateListener);

    // 处理来自 macOS 原生的导航请求（用于多窗口启动后进入指定页面）
    const MethodChannel channel = MethodChannel('window_control');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final args = (call.arguments as Map?) ?? const {};
        final String? route = args['route'] as String?;
        if (route != null && route.isNotEmpty) {
          _pendingRoute = route;
          // schedule navigation after first frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _router.go(route);
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _pendingRoute == route) {
              _router.go(route);
            }
          });
        }
      }
      return null;
    });
    _showSplashOverlay();
  }

  /// main.dart | _LinkMeAppState | _showSplashOverlay | 显示启动页
  /// 启动页显示2秒后自动进入主页
  void _showSplashOverlay() {
    _splashTimer?.cancel();
    if (!_showSplash) {
      setState(() {
        _showSplash = true;
      });
    }
    _splashTimer = Timer(const Duration(seconds: 2), _hideSplash);
  }

  /// main.dart | _LinkMeAppState | _hideSplash | 隐藏启动页
  void _hideSplash() {
    if (!_showSplash) return;
    _splashTimer?.cancel();
    setState(() {
      _showSplash = false;
      _lastForegroundTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.authStateListenable.removeListener(_authStateListener);
    _splashTimer?.cancel();
    _appFeatureProvider.dispose();
    _callProvider.onIncomingCall = null;
    super.dispose();
  }

  /// main.dart | _LinkMeAppState | _handleIncomingCall | 处理来电
  /// 作用：收到来电时显示来电界面
  /// @param incomingCall 来电信息
  void _handleIncomingCall(dynamic incomingCall) {
    if (!mounted) return;
    
    // 显示来电对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(incomingCall: incomingCall),
    );
  }

  void _handleAuthStateChanged() {
    if (!mounted || _routerRefreshScheduled) return;
    _routerRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _routerRefreshScheduled = false;
        return;
      }
      setState(() {
        _router = AppRouter.createRouter(_authProvider);
        final target = _pendingRoute;
        if (target != null && target.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _router.go(target);
          });
        }
      });
      _routerRefreshScheduled = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastForegroundTime == null ||
          now.difference(_lastForegroundTime!) >= _splashInterval) {
        _showSplashOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _chatProvider),
        ChangeNotifierProvider.value(value: _quickLinkProvider),
        ChangeNotifierProvider.value(value: _favoriteProvider),
        ChangeNotifierProvider.value(value: _pinnedMessageProvider),
        ChangeNotifierProvider.value(value: _walletProvider),
        ChangeNotifierProvider.value(value: _subscriptionProvider),
        ChangeNotifierProvider.value(value: _policyProvider),
        ChangeNotifierProvider.value(value: _communityProvider),
        ChangeNotifierProvider.value(value: _appFeatureProvider),
        ChangeNotifierProvider.value(value: _notesProvider),
        ChangeNotifierProvider.value(value: _zenNotesInvitationProvider),
        ChangeNotifierProvider.value(value: _callProvider),
      ],
      // 注意：只监听 isInitializing 这一字段，
      // 避免资料更新等其他 notifyListeners 触发 MaterialApp 重建
      child: Selector<AuthProvider, bool>(
        selector: (_, p) => p.isInitializing,
        builder: (context, isInitializing, _) {
          if (isInitializing) {
            return MaterialApp(
              title: 'LinkMe',
              theme: AppTheme.light,
              home: const Scaffold(
                body: Center(
                  child: SizedBox(
                    height: 32,
                    child: LinkMeLoader(fontSize: 22),
                  ),
                ),
              ),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => _buildWithSplash(child),
            );
          }

          return MaterialApp.router(
            title: 'LinkMe',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => _buildWithSplash(child),
          );
        },
      ),
    );
  }

  Widget _buildWithSplash(Widget? child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child ?? const SizedBox.shrink(),
        if (_showSplash) const SplashOverlay(),
      ],
    );
  }
}

/// main.dart | SplashOverlay | 启动页覆盖层
/// 显示2秒后自动消失，背景图不拉伸
class SplashOverlay extends StatelessWidget {
  const SplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/new_start_backimge.png',
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            // 如果图片加载失败，显示错误信息
            return Center(
              child: Text(
                '启动页图片加载失败',
                style: TextStyle(color: Colors.red),
              ),
            );
          },
        ),
      ),
    );
  }
}
