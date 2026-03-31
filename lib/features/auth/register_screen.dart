import 'dart:async';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/auth_service.dart' show EmailCodeScene;
import '../../core/utils/app_router.dart';
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/privacy_agreement_widget.dart';
// Desktop window control is handled natively on macOS; no Dart call is needed here.

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _codeTimer;
  int _countdown = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get _isDesktop {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.macOS ||
        p == TargetPlatform.windows ||
        p == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // macOS: window is fixed-size by default in native code.
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerWithEmailCode(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
    );

    if (success && mounted) {
      _navigateAfterAuth(authProvider);
    } else if (mounted) {
      context.showErrorToast(authProvider.errorMessage ?? '注册失败');
    }
  }

  void _navigateAfterAuth(AuthProvider auth) {
    switch (auth.onboardingStage) {
      case OnboardingStage.profile:
        context.go(AppRouter.onboardingProfile);
        break;
      case OnboardingStage.password:
        context.go(AppRouter.onboardingPassword);
        break;
      case OnboardingStage.done:
        context.go(AppRouter.main);
        break;
    }
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    if (!_validateEmailField()) return;
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.requestEmailCode(
      _emailController.text.trim(),
      scene: EmailCodeScene.register,
    );
    if (!mounted) return;
    if (!result.success) {
      context.showErrorToast(result.message);
      return;
    }
    context.showSuccessToast('验证码已发送');
    if (result.debugCode != null) {
      context.showInfoToast('测试验证码：${result.debugCode}');
    }
    _startCountdown();
  }

  bool _validateEmailField() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      context.showErrorToast('请输入邮箱');
      return false;
    }
    final emailReg = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailReg.hasMatch(email)) {
      context.showErrorToast('请输入有效的邮箱地址');
      return false;
    }
    return true;
  }

  void _startCountdown() {
    _codeTimer?.cancel();
    setState(() => _countdown = 60);
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: _isDesktop
                ? AppColors.desktopSoftGradient
                : AppColors.backgroundGradient,
          ),
          child: SafeArea(
            top: !_isDesktop,
            bottom: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.largePadding),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: _isDesktop ? 440 : 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: _isDesktop ? 18 : 12),

                              _buildTitleBlock(),

                              SizedBox(height: _isDesktop ? 32 : 40),

                              // 注册表单
                              _buildRegisterForm(),

                              const SizedBox(height: 24),

                              // 注册按钮
                              _buildRegisterButton(),

                              const SizedBox(height: 16),

                              // 登录链接
                              _buildLoginLink(),

                              const SizedBox(height: 24),

                              // 隐私政策和测试协议
                              const PrivacyAgreementWidget(),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '邮箱注册',
          style: AppTextStyles.h5.copyWith(
            fontSize: _isDesktop ? 34 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '输入邮箱并完成验证码验证，后续资料将在引导页中完善。',
          style: AppTextStyles.body2.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                hint: '邮箱',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return '请输入邮箱';
                final emailReg = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                if (!emailReg.hasMatch(v)) return '请输入有效的邮箱地址';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                hint: '验证码',
                icon: Icons.verified_outlined,
              ).copyWith(
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: (_countdown > 0) ? null : _sendCode,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        backgroundColor: (_countdown > 0)
                            ? AppColors.textSecondary.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _countdown > 0 ? '$_countdown s' : '获取验证码',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _countdown > 0
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return '请输入验证码';
                if (v.length < 4) return '验证码格式错误';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    final fillColor = Colors.white.withValues(alpha: _isDesktop ? 0.6 : 1.0);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      prefixIcon: Icon(icon, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: _isDesktop ? 0.2 : 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return LoadingButton(
          onPressed: authProvider.isLoading ? null : _handleRegister,
          isLoading: authProvider.isLoading,
          height: 44,
          child: const Text(
            '注册',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textWhite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '已有账户？',
          style: AppTextStyles.body2.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRouter.login),
          child: Text(
            '立即登录',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
