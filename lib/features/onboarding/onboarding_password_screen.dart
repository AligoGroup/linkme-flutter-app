import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_router.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../widgets/common/loading_button.dart';

class OnboardingPasswordScreen extends StatefulWidget {
  const OnboardingPasswordScreen({super.key});

  @override
  State<OnboardingPasswordScreen> createState() =>
      _OnboardingPasswordScreenState();
}

class _OnboardingPasswordScreenState extends State<OnboardingPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AnimationController _loadingController;
  bool _showForm = false;
  int _playCount = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this);
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playCount += 1;
        if (_playCount < 2) {
          _loadingController.forward(from: 0);
        } else {
          setState(() => _showForm = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _showForm ? _buildForm(context) : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Lottie.asset(
        'assets/animations/Loading (2).json',
        controller: _loadingController,
        onLoaded: (composition) {
          _loadingController
            ..duration = composition.duration
            ..forward();
        },
        repeat: false,
        width: 220,
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width > 600 ? width * 0.2 : 24.0;
    const double buttonRadius = 22;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            '守护你的 LinkMe 身份',
            textAlign: TextAlign.center,
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '建议设置至少 8 位密码，包含字母和数字',
            textAlign: TextAlign.center,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildPasswordField(
                  controller: _passwordController,
                  obscure: _obscurePassword,
                  hint: '设置密码',
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _confirmController,
                  obscure: _obscureConfirm,
                  hint: '确认密码',
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return '请再次输入密码';
                    if (v != _passwordController.text) return '两次输入不一致';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleSkip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(buttonRadius),
                    ),
                  ),
                  child: const Text(
                    '跳过',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) => LoadingButton(
                    onPressed:
                        auth.isLoading ? null : () => _handleSubmit(auth),
                    isLoading: auth.isLoading,
                    height: 48,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(buttonRadius),
                      ),
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required String hint,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator ??
          (value) {
            final v = value ?? '';
            if (v.length < 6) return '密码至少 6 位';
            return null;
          },
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _handleSubmit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.setupPasswordStep(_passwordController.text.trim());
    if (!mounted) return;
    if (!ok) {
      context.showErrorToast(auth.errorMessage ?? '设置失败');
      return;
    }
    context.go(AppRouter.onboardingWelcome);
  }

  Future<void> _handleSkip() async {
    final auth = context.read<AuthProvider>();
    await auth.skipPasswordStep();
    if (!mounted) return;
    context.go(AppRouter.onboardingWelcome);
  }
}
