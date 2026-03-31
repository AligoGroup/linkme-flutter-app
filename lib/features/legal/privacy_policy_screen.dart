import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/policy_provider.dart';
import '../../widgets/common/lite_html.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isTestingAgreement;
  const PrivacyPolicyScreen({super.key, this.isTestingAgreement = false});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

    final code = widget.isTestingAgreement ? 'TESTING' : 'PRIVACY';
    return Scaffold(
      extendBodyBehindAppBar: !isMobile,
      appBar: AppBar(
        automaticallyImplyLeading: isMobile, // 移动端显示系统返回箭头（最左侧）
        centerTitle: true,
        backgroundColor: isMobile ? Colors.white : Colors.transparent,
        elevation: 0,
        toolbarHeight: isMobile ? kToolbarHeight : 30,
        iconTheme: const IconThemeData(color: AppColors.textPrimary), // 移动端返回箭头颜色
        title: Consumer<PolicyProvider>(builder: (_, pp, __) {
          final p = pp.policyOf(code);
          final title = p?.title ?? (widget.isTestingAgreement ? '测试协议' : '隐私政策');
          return Text(title, style: AppTextStyles.h6);
        }),
        // 桌面端仍保持右上角“返回”文本按钮；移动端不需要
        actions: isMobile
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: ButtonStyle(
                      padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                      minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                      backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
                      foregroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.hovered)) {
                          return AppColors.primaryLight;
                        }
                        return AppColors.primary;
                      }),
                    ),
                    child: const Text('返回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        // 顶部/底部保留间距；左右不加 padding，确保滚动条“贴近窗口最右侧”
        padding: EdgeInsets.only(
          top: isMobile ? 0 : (MediaQuery.of(context).padding.top + 30),
          bottom: 16,
        ),
        child: Consumer<PolicyProvider>(builder: (_, pp, __) {
          final p = pp.policyOf(code);
          if (p == null || p.enabled != true) {
            return const Center(child: Text('暂未启用'));
          }
          final content = Container(
            // 内容本身保持左右内边距，避免文字贴边；滚动条不受影响
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: LiteHtml(
              p.content,
              lineHeight: 1.6,
              style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary),
            ),
          );

          final scrollView = SingleChildScrollView(
            controller: _scrollController,
            child: content,
          );

          // 两端统一使用细小滚动条，贴近右侧窗口边缘
          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 3.0,
            radius: const Radius.circular(2),
            child: scrollView,
          );
        }),
      ),
    );
  }
}
