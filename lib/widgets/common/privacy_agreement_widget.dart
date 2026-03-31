import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/legal/privacy_policy_screen.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/policy_provider.dart';

class PrivacyAgreementWidget extends StatelessWidget {
  const PrivacyAgreementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Consumer<PolicyProvider>(builder: (_, pp, __) {
            final showPrivacy = pp.enabled('PRIVACY');
            final showTesting = pp.enabled('TESTING');
            final titlePrivacy = pp.policyOf('PRIVACY')?.title ?? '隐私政策';
            final titleTesting = pp.policyOf('TESTING')?.title ?? '测试协议';
            return RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.3),
                children: [
                  const TextSpan(text: '继续使用即表示您同意我们的 '),
                  if (showPrivacy)
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => _showPrivacyPolicy(context),
                        child: Text(titlePrivacy, style: AppTextStyles.caption.copyWith(color: AppColors.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  if (showPrivacy && showTesting) const TextSpan(text: ' 和 '),
                  if (showTesting)
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => _showTestingAgreement(context),
                        child: Text(titleTesting, style: AppTextStyles.caption.copyWith(color: AppColors.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(isTestingAgreement: false),
      ),
    );
  }

  void _showTestingAgreement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(isTestingAgreement: true),
      ),
    );
  }
}
