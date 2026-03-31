import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/chat/main_screen.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../../features/desktop/desktop_main_screen.dart';
import '../../features/chat/chat_detail_screen.dart';
import '../../features/friends/add_friend_screen.dart';
import '../../features/friends/friend_requests_screen.dart';
import '../../features/friends/friend_profile_screen.dart';
import '../../features/location/send_location_page.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/groups/group_info_screen.dart';
import '../../features/groups/group_list_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/favorites_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/account_deletion_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/wallet/transaction_history_screen.dart';
import '../../features/wallet/transaction_detail_screen.dart';
import '../../features/hot/hot_screen.dart';
import '../../features/hot/article_detail_screen.dart';
import '../../features/hot/publish_content_screen.dart';
import '../../features/community/community_notifications_screen.dart';
import '../../features/store/store_shell.dart';
import '../../features/profile/about_linkme_screen.dart';
import '../../features/onboarding/onboarding_profile_screen.dart';
import '../../features/onboarding/onboarding_password_screen.dart';
import '../../features/onboarding/onboarding_welcome_screen.dart';
import '../../features/notes/notes_home_screen.dart';
import '../../features/notes/zennotes_invitations_screen.dart';
import '../../features/academy/academy_home_screen.dart';
// 订阅号页使用 Navigator.push 打开，不声明在 GoRouter 中
import '../../shared/models/user.dart';
import '../../shared/models/wallet.dart';
import '../../shared/providers/auth_provider.dart';
import 'ios_style_route.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String onboardingProfile = '/onboarding/profile';
  static const String onboardingPassword = '/onboarding/password';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String main = '/';
  static const String chat = '/chat';
  static const String addFriend = '/add-friend';
  static const String friendRequests = '/friend-requests';
  static const String friendProfile = '/friend-profile';
  static const String profile = '/profile';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String accountDeletion = '/account-deletion';
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String transactionDetail = '/wallet/transaction-detail';
  static const String createGroup = '/create-group';
  static const String groupInfo = '/group-info';
  static const String groupsList = '/groups';
  static const String sendLocation = '/send-location';
  static const String subscriptions = '/subscriptions';
  static const String hot = '/hot';
  static const String hotArticle = '/hot/article';
  static const String hotPublish = '/hot/publish';
  static const String communityNotify = '/community-notify';
  static const String store = '/store';
  static const String aboutLinkMe = '/about-linkme';
  static const String notes = '/notes';
  static const String zenNotesInvitations = '/zennotes-invitations';
  static const String academy = '/academy';

  static GoRouter createRouter(AuthProvider authProvider) => GoRouter(
        initialLocation: main,
        routes: [
          // 认证相关路由
          GoRoute(
            path: login,
            name: 'login',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionDuration: const Duration(milliseconds: 380),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                final slide =
                    Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOut));
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
            ),
          ),
          GoRoute(
            path: register,
            name: 'register',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RegisterScreen(),
              transitionDuration: const Duration(milliseconds: 420),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic);
                final slide = Tween<Offset>(
                        begin: const Offset(0, 0.12), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOut));
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
            ),
          ),
          GoRoute(
            path: onboardingProfile,
            name: 'onboarding-profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              transitionDuration: const Duration(milliseconds: 320),
              child: const OnboardingProfileScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(opacity: fade, child: child);
              },
            ),
          ),
          GoRoute(
            path: onboardingPassword,
            name: 'onboarding-password',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              transitionDuration: const Duration(milliseconds: 320),
              child: const OnboardingPasswordScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(opacity: fade, child: child);
              },
            ),
          ),
          GoRoute(
            path: onboardingWelcome,
            name: 'onboarding-welcome',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              transitionDuration: const Duration(milliseconds: 380),
              child: const OnboardingWelcomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                );
                return FadeTransition(opacity: fade, child: child);
              },
            ),
          ),

          // 主界面路由
          GoRoute(
            path: main,
            name: 'main',
            pageBuilder: (context, state) {
              final isMacDesktop =
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
              final child =
                  isMacDesktop ? const DesktopMainScreen() : const MainScreen();
              final entryTag =
                  state.extra is Map ? (state.extra as Map)['entry'] : null;
              final needsAnimatedEntry =
                  entryTag == 'onboarding' || entryTag == 'login';
              if (needsAnimatedEntry) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: const Duration(milliseconds: 420),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final slide = Tween<Offset>(
                      begin: const Offset(-0.08, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    );
                    return SlideTransition(
                      position: slide,
                      child: FadeTransition(opacity: fade, child: child),
                    );
                  },
                );
              }
              return NoTransitionPage(key: state.pageKey, child: child);
            },
          ),

          // 聊天相关路由
          GoRoute(
            path: '$chat/:contactId',
            name: 'chat',
            pageBuilder: (context, state) {
              final contactId = state.pathParameters['contactId']!;
              final isGroup = state.uri.queryParameters['type'] == 'group';
              return buildIOSStylePage(
                context: context,
                state: state,
                child: ChatDetailScreen(
                  contactId: contactId,
                  isGroup: isGroup,
                ),
              );
            },
          ),

          // 好友相关路由
          GoRoute(
            path: addFriend,
            name: 'add-friend',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const AddFriendScreen(),
            ),
          ),
          GoRoute(
            path: friendRequests,
            name: 'friend-requests',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const FriendRequestsScreen(),
            ),
          ),
          GoRoute(
            path: '$friendProfile/:userId',
            name: 'friend-profile',
            pageBuilder: (context, state) {
              final userId = state.pathParameters['userId']!;
              // TODO: 从Provider或API获取用户详细信息
              // 这里先创建一个临时的User对象用于路由
              return buildIOSStylePage(
                context: context,
                state: state,
                child: FriendProfileScreen(
                  user: User(
                    id: int.parse(userId),
                    username: 'user_$userId',
                    email: 'user$userId@example.com',
                    nickname: '用户$userId',
                    status: UserStatus.online,
                  ),
                  isFriend: true,
                ),
              );
            },
          ),

          // 个人中心路由
          // 热点页
          GoRoute(
            path: hot,
            name: 'hot',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HotScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                // app_router.dart/GoRoute/transitionsBuilder: 实现"二楼"推挤效果
                // 进入二楼：热点榜单从顶部（Offset(0, -1)）滑入，同时列表从底部（Offset(0, 1)）被挤出
                // 退出二楼：热点榜单向上滑出（Offset(0, -1)），同时列表从底部（Offset(0, 1)）进入

                // 新页面（热点榜单）的动画：从顶部进入/退出
                // animation: 进入时从 0.0 到 1.0，退出时从 1.0 到 0.0
                final hotPageAnimation = Tween<Offset>(
                  begin: const Offset(0, -1), // 从顶部开始
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ));

                // 底层页面（列表）的动画：从底部被挤出/进入
                // secondaryAnimation: 进入时从 1.0 到 0.0（底层页面被推下），退出时从 0.0 到 1.0（底层页面从底部进入）
                // 注意：在 go_router 的 CustomTransitionPage 中，我们只能控制新页面的动画
                // 底层页面的动画由系统自动处理，底层页面的"推挤"效果需要在 MainScreen 中通过监听路由变化来实现

                // 新页面（热点榜单）：从顶部进入/退出
                return SlideTransition(
                  position: hotPageAnimation,
                  child: child,
                );
              },
            ),
          ),
          // 文章详情
          GoRoute(
            path: hotArticle,
            name: 'hot-article',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: ArticleDetailScreen(
                  data: (state.extra ?? const <String, dynamic>{})
                      as Map<String, dynamic>),
            ),
          ),

          // 商城壳：拥有独立的底部导航，不带返回图标（保留手势返回）
          GoRoute(
            path: store,
            name: 'store',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const StoreShell(),
            ),
          ),
          GoRoute(
            path: notes,
            name: 'notes',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const NotesHomeScreen(),
            ),
          ),
          GoRoute(
            path: zenNotesInvitations,
            name: 'zennotes-invitations',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const ZenNotesInvitationsScreen(),
            ),
          ),
          GoRoute(
            path: aboutLinkMe,
            name: 'about-linkme',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const AboutLinkMeScreen(),
            ),
          ),
          GoRoute(
            path: academy,
            name: 'academy',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const AcademyHomeScreen(),
            ),
          ),
          // 发布内容（热点榜单）
          GoRoute(
            path: hotPublish,
            name: 'hot-publish',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: PublishContentScreen(
                initialArticle: state.extra is Map<String, dynamic>
                    ? Map<String, dynamic>.from(state.extra as Map)
                    : null,
              ),
            ),
          ),
          // 社区通知
          GoRoute(
            path: communityNotify,
            name: 'community-notify',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const CommunityNotificationsScreen(),
            ),
          ),
          GoRoute(
            path: profile,
            name: 'profile',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: favorites,
            name: 'favorites',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const FavoritesScreen(),
            ),
          ),
          GoRoute(
            path: accountDeletion,
            name: 'account-deletion',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const AccountDeletionScreen(),
            ),
          ),
          GoRoute(
            path: wallet,
            name: 'wallet',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const WalletScreen(),
            ),
          ),
          GoRoute(
            path: walletTransactions,
            name: 'wallet-transactions',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const TransactionHistoryScreen(),
            ),
          ),
          GoRoute(
            path: transactionDetail,
            name: 'transaction-detail',
            pageBuilder: (context, state) {
              final transaction = state.extra as WalletTransaction;
              return buildIOSStylePage(
                context: context,
                state: state,
                child: TransactionDetailScreen(transaction: transaction),
              );
            },
          ),

          // 群聊相关路由
          GoRoute(
            path: createGroup,
            name: 'create-group',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const CreateGroupScreen(),
            ),
          ),
          GoRoute(
            path: '$groupInfo/:groupId',
            name: 'group-info',
            pageBuilder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              return buildIOSStylePage(
                context: context,
                state: state,
                child: GroupInfoScreen(groupId: groupId),
              );
            },
          ),
          // 群聊列表
          GoRoute(
            path: groupsList,
            name: 'groups',
            pageBuilder: (context, state) => buildIOSStylePage(
              context: context,
              state: state,
              child: const GroupListScreen(),
            ),
          ),

          // 发送位置
          GoRoute(
            path: '$sendLocation/:contactId',
            name: 'send-location',
            pageBuilder: (context, state) {
              final contactId = state.pathParameters['contactId']!;
              final isGroup = state.uri.queryParameters['type'] == 'group';
              return buildIOSStylePage(
                context: context,
                state: state,
                child: SendLocationPage(contactId: contactId, isGroup: isGroup),
              );
            },
          ),
        ],
        // 仅在登录状态变化时刷新路由，避免资料更新触发重建导致Tab回到首页
        refreshListenable: authProvider.authStateListenable,
        redirect: (context, state) {
          final isLoggedIn = authProvider.isLoggedIn;
          final location = state.matchedLocation;
          final isAuthRoute = location == login || location == register;
          final isOnboardingRoute = location.startsWith('/onboarding');
          final isWelcomeRoute = location == onboardingWelcome;
          final stage = authProvider.onboardingStage;
          if (authProvider.navigationLocked) {
            return null;
          }

          if (!isLoggedIn) {
            if (isAuthRoute) return null;
            return login;
          }

          if (isLoggedIn && isAuthRoute) {
            return main;
          }

          if (stage == OnboardingStage.profile &&
              location != onboardingProfile) {
            return onboardingProfile;
          }

          if (stage == OnboardingStage.password &&
              location != onboardingPassword) {
            return onboardingPassword;
          }

          if (stage == OnboardingStage.done &&
              isOnboardingRoute &&
              !isWelcomeRoute) {
            return main;
          }

          return null;
        },
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('页面未找到: ${state.error}'),
          ),
        ),
      );
}
