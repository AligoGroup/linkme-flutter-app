import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../widgets/common/linkme_loader.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/models/user.dart';
import '../../widgets/custom/user_avatar.dart';
import '../legal/privacy_policy_screen.dart';
import '../../shared/providers/policy_provider.dart';
import '../../shared/providers/app_feature_provider.dart';
import 'widgets/avatar_picker.dart';
import '../../core/utils/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.user;

            if (user == null) {
              return const Center(
                child: Text('用户信息加载中...'),
              );
            }

            final featureProvider = context.watch<AppFeatureProvider>();
            final slivers = <Widget>[
              SliverToBoxAdapter(
                child: _buildUserInfoSection(context, user),
              ),
            ];

            if (featureProvider.walletEnabled) {
              slivers.add(
                SliverToBoxAdapter(
                  child: _buildWalletSection(context, user.id.toString()),
                ),
              );
            }

            slivers.add(
              SliverToBoxAdapter(
                child: _buildFunctionList(context, authProvider),
              ),
            );

            return CustomScrollView(slivers: slivers);
          },
        ),
      ),
    );
  }

  // 个人信息区域
  Widget _buildUserInfoSection(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像和基本信息
          Row(
            children: [
              // 头像
              GestureDetector(
                onTap: () => _editProfile(context),
                child: Stack(
                  children: [
                    UserAvatar(
                      imageUrl: user.avatar,
                      name: user.nickname ?? user.username,
                      size: 60,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.nickname ?? user.username,
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // 在线状态指示器（使用WebSocket连接状态为准，保证更新资料后不误判）
                        Consumer<ChatProvider>(
                          builder: (context, chat, _) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: chat.isConnected
                                  ? AppColors.success
                                  : AppColors.textLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (user.signature != null &&
                        user.signature!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.signature!,
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 编辑按钮
              IconButton(
                onPressed: () => _editProfile(context),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 钱包功能区域
  Widget _buildWalletSection(BuildContext context, String userId) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        // 首次加载钱包数据
        if (walletProvider.wallet == null && !walletProvider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            walletProvider.loadWallet(userId);
          });
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '我的钱包',
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/wallet'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '全部',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (walletProvider.isLoading)
                const Center(
                    child:
                        SizedBox(height: 28, child: LinkMeLoader(fontSize: 18)))
              else if (walletProvider.errorMessage != null)
                Center(
                  child: Text(
                    walletProvider.errorMessage!,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // 余额显示
                    Expanded(
                      child: _buildWalletItem(
                        icon: Icons.account_balance_wallet,
                        title: '余额',
                        value: walletProvider.formattedBalance,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // 银行卡数量
                    Expanded(
                      child: _buildWalletItem(
                        icon: Icons.credit_card,
                        title: '银行卡',
                        value: '${walletProvider.bankCardCount}张',
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 功能列表
  Widget _buildFunctionList(BuildContext context, AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 我的收藏
          _buildListItem(
            context,
            icon: Icons.favorite_outline,
            title: '我的收藏',
            onTap: () => context.push('/favorites'),
          ),

          const Divider(height: 1, indent: 56),

          // 设置
          _buildListItem(
            context,
            icon: Icons.settings_outlined,
            title: '设置',
            onTap: () => _showSettings(context),
          ),

          const Divider(height: 1, indent: 56),

          // 平台政策（根据启用状态显示）
          Builder(builder: (ctx) {
            final pp = ctx.watch<PolicyProvider>();
            final tiles = <Widget>[];
            if (pp.enabled('PRIVACY')) {
              tiles.add(_buildListItem(ctx,
                  icon: Icons.privacy_tip_outlined,
                  title: pp.policyOf('PRIVACY')?.title ?? '隐私政策',
                  onTap: () => _showPrivacyPolicy(ctx)));
              tiles.add(const Divider(height: 1, indent: 56));
            }
            if (pp.enabled('TESTING')) {
              tiles.add(_buildListItem(ctx,
                  icon: Icons.description_outlined,
                  title: pp.policyOf('TESTING')?.title ?? '测试协议',
                  onTap: () => _showTestingAgreement(ctx)));
              tiles.add(const Divider(height: 1, indent: 56));
            }
            return Column(children: tiles);
          }),

          // 关于
          _buildListItem(
            context,
            icon: Icons.info_outline,
            title: '关于LinkMe',
            onTap: () => _showAbout(context),
          ),

          const Divider(height: 1, indent: 56),

          // 注销账号
          _buildListItem(
            context,
            icon: Icons.person_off_outlined,
            title: '注销账号',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => context.push(AppRouter.accountDeletion),
          ),

          const Divider(height: 1, indent: 56),

          // 退出登录
          _buildListItem(
            context,
            icon: Icons.logout,
            title: '退出登录',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: iconColor ?? AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1.copyWith(
                    color: titleColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    _showEditProfileDialog(context);
  }

  void _showSettings(BuildContext context) {
    context.push(AppRouter.settings);
  }

  void _showAbout(BuildContext context) {
    context.push(AppRouter.aboutLinkMe);
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await authProvider.logout();
              if (rootContext.mounted) {
                rootContext.go(AppRouter.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              '退出',
              style: TextStyle(color: AppColors.textWhite),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user!;

    final nicknameController = TextEditingController(text: user.nickname);
    final signatureController =
        TextEditingController(text: user.signature ?? '');
    String? updatedAvatarUrl = user.avatar;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑个人资料'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头像选择器
                AvatarPicker(
                  currentAvatarUrl: updatedAvatarUrl,
                  userName: user.nickname ?? user.username,
                  onAvatarUploaded: (url) async {
                    setState(() {
                      updatedAvatarUrl = url.isEmpty ? null : url;
                    });

                    // 头像上传成功后立即保存到服务器
                    if (url.isNotEmpty) {
                      final success = await authProvider.updateProfile(
                        avatar: url,
                      );

                      if (success && context.mounted) {
                        context.showSuccessToast('头像已更新');
                      } else if (context.mounted) {
                        context.showErrorToast('头像保存失败');
                      }
                    }
                  },
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    hintText: '请输入昵称',
                  ),
                  maxLength: 20,
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: signatureController,
                  decoration: const InputDecoration(
                    labelText: '个性签名',
                    hintText: '写点什么介绍一下自己吧',
                  ),
                  maxLength: 50,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nicknameController.dispose();
                signatureController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nickname = nicknameController.text.trim();
                final signature = signatureController.text.trim();

                if (nickname.isEmpty) {
                  context.showErrorToast('昵称不能为空');
                  return;
                }

                final success = await authProvider.updateProfile(
                  nickname: nickname,
                  signature: signature.isEmpty ? null : signature,
                  avatar: updatedAvatarUrl,
                );

                nicknameController.dispose();
                signatureController.dispose();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (success) {
                    context.showSuccessToast('个人资料更新成功');
                  } else {
                    context.showErrorToast('更新失败，请重试');
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const PrivacyPolicyScreen(isTestingAgreement: false),
      ),
    );
  }

  void _showTestingAgreement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const PrivacyPolicyScreen(isTestingAgreement: true),
      ),
    );
  }
}
