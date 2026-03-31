import 'dart:async';

import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_router.dart';
import '../../core/widgets/unified_toast.dart';
import '../../shared/providers/auth_provider.dart';
import '../../widgets/common/loading_button.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _codeController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _hasConfirmed = false;
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _codeController.dispose();
    _reasonController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? '';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('注销账号'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRiskCard(),
                const SizedBox(height: 20),
                _buildVerificationHeader(email),
                const SizedBox(height: 12),
                _buildCodeField(auth.isLoading),
                const SizedBox(height: 20),
                _buildReasonField(),
                const SizedBox(height: 20),
                _buildConfirmation(),
                const SizedBox(height: 28),
                LoadingButton(
                  onPressed: _hasConfirmed ? () => _submit(auth) : null,
                  isLoading: auth.isLoading,
                  child: const Text('我已知晓风险并注销账号'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textWhite,
                    disabledBackgroundColor: AppColors.error.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskCard() {
    const risks = [
      '注销后将立即清空聊天记录、好友关系、钱包资产等所有数据，无法找回',
      '相同邮箱/手机号一段时间内不可再次注册同一账号',
      '若账号存在安全或合规风险，平台保留驳回或延期处理的权利',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.largeRadius),
        border: Border.all(color: AppColors.error.withOpacity(.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '注销风险提示',
                  style: AppTextStyles.h5.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...risks.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(color: AppColors.error, fontSize: 16)),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.body2,
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

  Widget _buildVerificationHeader(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '安全校验',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '发送至$email',
          style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '验证码将发送至此邮箱，用于身份验证。',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildCodeField(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: '邮箱验证码',
              hintText: '请输入6位验证码',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: (_secondsLeft > 0 || isLoading)
                ? null
                : () => _sendCode(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(.6)),
            ),
            child: Text(
              _secondsLeft > 0 ? '重新发送(${_secondsLeft}s)' : '发送验证码',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('注销原因 (选填)', style: AppTextStyles.h6),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          style: AppTextStyles.input,
          decoration: InputDecoration(
            hintText: '简要描述注销原因，帮助我们改进体验',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CheckboxListTile(
        value: _hasConfirmed,
        onChanged: (value) {
          setState(() => _hasConfirmed = value ?? false);
        },
        title: Text(
          '我已阅读以上风险说明，并确认主动注销账号。',
          style: AppTextStyles.body2,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.error,
      ),
    );
  }

  Future<void> _sendCode(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final result = await auth.requestAccountDeletionCode();
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

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _submit(AuthProvider auth) async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      context.showErrorToast('请输入完整的6位验证码');
      return;
    }
    if (!_hasConfirmed) {
      context.showInfoToast('请先勾选风险确认');
      return;
    }
    final reason = _reasonController.text.trim();
    final ok = await auth.deleteAccount(
      code: code,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (!ok) {
      final msg = auth.errorMessage ?? '注销失败，请稍后重试';
      context.showErrorToast(msg);
      return;
    }
    context.showSuccessToast('账号已成功注销');
    context.go(AppRouter.login);
  }
}
