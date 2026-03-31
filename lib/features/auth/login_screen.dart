import 'dart:async';
import 'dart:developer';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_router.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/auth_service.dart' show EmailCodeScene;
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/privacy_agreement_widget.dart';
import '../../core/widgets/unified_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMethod { code, password }

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Tunable measurements for desktop layout
  static const double _brandSize = 18; // desktop brand size (icon == text)
  static const double _mobileBrandSize = 26; // mobile centered brand size
  static const double _hPadding = 16; // horizontal padding of page
  static const double _formWidth = 320; // input/button width

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut);

  bool _obscure = true;
  _LoginMethod _method = _LoginMethod.code;
  Timer? _codeTimer;
  int _countdown = 0;

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
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print("触发登录");
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    bool ok = false;
    if (_method == _LoginMethod.code) {
      ok = await auth.loginWithEmailCode(
          email: email, code: _codeController.text.trim());
    } else {
      print("进入登录流程");
      ok = await auth.loginWithEmailPassword(
          email: email, password: _passwordController.text);
    }
    if (!mounted) return;

    // Show top banner on failure
    if (!ok) {
      final msg = auth.errorMessage ?? '登录失败，请稍后重试';
      context.showErrorToast(msg);
      return;
    }
    auth.setNavigationLock(true);
    try {
      await _playLoginSuccessAnimation();
    } finally {
      auth.setNavigationLock(false);
    }
    if (!mounted) return;
    _navigateAfterAuth(auth);
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
        context.go(AppRouter.main, extra: const {'entry': 'login'});
        break;
    }
  }

  Future<void> _playLoginSuccessAnimation() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.white,
      builder: (_) => const _LoginSuccessOverlay(),
    );
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    if (!_validateEmailField()) return;
    final auth = context.read<AuthProvider>();
    final result = await auth.requestEmailCode(
      _emailController.text.trim(),
      scene: EmailCodeScene.login,
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

  void _toggleMethod() {
    setState(() {
      _method = _method == _LoginMethod.code
          ? _LoginMethod.password
          : _LoginMethod.code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: _isDesktop
                    ? AppColors.desktopSoftGradient
                    : AppColors.backgroundGradient,
              ),
              child: SafeArea(
                top: !_isDesktop,
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _hPadding),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isDesktop)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: _buildTopRightBrand(),
                              ),
                            ),
                          SizedBox(height: _isDesktop ? 32 : 48),
                          if (!_isDesktop) ...[
                            Center(child: _buildCenteredBrandLarge()),
                            const SizedBox(height: 24),
                          ],
                          Center(child: _buildWelcomeTexts()),
                          const SizedBox(height: 20),
                          Center(child: _buildFormArea()),
                          const Spacer(),
                          const SizedBox(height: 140),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(child: _buildMethodCircleToggle()),
            ),
          ],
        ),
      ),
    );
  }

  // 顶部右侧品牌（图标 + 文案），图标与文字同尺寸
  Widget _buildTopRightBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _brandSize + 6,
          height: _brandSize + 6,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.chat_bubble_rounded,
              color: AppColors.textWhite, size: _brandSize),
        ),
        const SizedBox(width: 8),
        Text(
          'LinkMe',
          style: TextStyle(
            fontSize: _brandSize,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  // 移动端：居中的大号品牌，放在“欢迎回来”上方
  Widget _buildCenteredBrandLarge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _mobileBrandSize + 8,
          height: _mobileBrandSize + 8,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.chat_bubble_rounded,
              color: AppColors.textWhite, size: _mobileBrandSize),
        ),
        const SizedBox(width: 10),
        Text(
          'LinkMe',
          style: TextStyle(
            fontSize: _mobileBrandSize,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  // 欢迎文案 + 副标题（居中）
  Widget _buildWelcomeTexts() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('欢迎回来',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('🌍 连接世界里的你我',
            style:
                AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  // 表单 + 隐私提示 + 登录按钮 + 注册
  Widget _buildFormArea() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _formWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _decoratedField(
                  controller: _emailController,
                  hint: '邮箱',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return '请输入邮箱';
                    final emailReg =
                        RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                    if (!emailReg.hasMatch(v)) return '请输入有效的邮箱地址';
                    return null;
                  },
                  obscure: false,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _method == _LoginMethod.code
                      ? _buildCodeField()
                      : _buildPasswordField(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const PrivacyAgreementWidget(),
          const SizedBox(height: 12),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => LoadingButton(
              onPressed: auth.isLoading ? null : _handleLogin,
              isLoading: auth.isLoading,
              height: 42,
              child: const Text(
                '登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('还没有账户？',
                  style: AppTextStyles.body2
                      .copyWith(color: AppColors.textSecondary)),
              TextButton(
                onPressed: () => context.go(AppRouter.register),
                child: Text('立即注册',
                    style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildMethodCircleToggle() {
    final bool isCode = _method == _LoginMethod.code;
    final IconData icon =
        isCode ? Icons.lock_outline : Icons.mark_email_read_outlined;
    final String caption = isCode ? '切换密码登录' : '切换验证码登录';
    return Column(
      children: [
        GestureDetector(
          onTap: _toggleMethod,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCodeField() {
    final baseDecoration = _inputDecoration(
      hint: '验证码',
      icon: Icons.shield_moon_outlined,
    );
    return TextFormField(
      key: const ValueKey('code_login'),
      controller: _codeController,
      keyboardType: TextInputType.number,
      decoration: baseDecoration.copyWith(
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _buildCodeSuffixButton(
            onTap: _sendCode,
            countdown: _countdown,
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (value) {
        if (_method != _LoginMethod.code) return null;
        final v = value?.trim() ?? '';
        if (v.isEmpty) return '请输入验证码';
        if (v.length < 4) return '验证码格式错误';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _decoratedField(
      key: const ValueKey('password_login'),
      controller: _passwordController,
      hint: '密码',
      icon: Icons.lock_outline,
      obscure: true,
      validator: (value) {
        if (_method != _LoginMethod.password) return null;
        if (value == null || value.isEmpty) return '请输入密码';
        if (value.length < 6) return '密码长度至少6位';
        return null;
      },
    );
  }

  Widget _buildCodeSuffixButton({
    required VoidCallback onTap,
    required int countdown,
  }) {
    final bool disabled = countdown > 0;
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: disabled ? null : onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: disabled
              ? AppColors.textSecondary.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          disabled ? '$countdown s' : '获取验证码',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: disabled ? AppColors.textSecondary : AppColors.primary,
          ),
        ),
      ),
    );
  }

  // 紧凑型输入框
  Widget _decoratedField({
    Key? key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final bool isMobile = !_isDesktop;
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: obscure ? _obscure : false,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        // 移动端：稍微加深背景色以增强辨识度；桌面端维持半透明白
        fillColor: isMobile
            ? const Color(0xFFF3F4F6)
            : Colors.white.withValues(alpha: 0.6),
        prefixIcon: Icon(icon, size: isMobile ? 20 : 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isMobile
                ? const Color(0xFFE6E8EA)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
      validator: validator,
      textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (obscure) _handleLogin();
      },
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    final bool isMobile = !_isDesktop;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isMobile
          ? const Color(0xFFF3F4F6)
          : Colors.white.withValues(alpha: 0.6),
      prefixIcon: Icon(icon, size: isMobile ? 20 : 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isMobile
              ? const Color(0xFFE6E8EA)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _LoginSuccessOverlay extends StatefulWidget {
  const _LoginSuccessOverlay();

  @override
  State<_LoginSuccessOverlay> createState() => _LoginSuccessOverlayState();
}

class _LoginSuccessOverlayState extends State<_LoginSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_popped) {
        _popped = true;
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Lottie.asset(
        'assets/animations/Loading (2).json',
        controller: _controller,
        onLoaded: (composition) {
          _controller
            ..duration = composition.duration
            ..forward();
        },
        repeat: false,
        width: 220,
      ),
    );
  }
}
