import 'dart:ui';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../widgets/common/linkme_loader.dart';

/// 统一提示弹窗系统
/// 样式：白色背景，绿色勾勾，深灰色小圆角边框
class UnifiedToast {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// 显示成功提示
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: message,
      isSuccess: true,
      duration: duration,
    );
  }

  /// 显示错误提示
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showToast(
      context,
      message: message,
      isSuccess: false,
      duration: duration,
    );
  }

  /// 显示加载提示
  static void showLoading(
    BuildContext context,
    String message,
  ) {
    _showToast(
      context,
      message: message,
      isSuccess: null, // null表示加载状态
      duration: null, // 不自动消失
    );
  }

  /// 隐藏当前显示的提示
  static void hide() {
    try {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
      }
    } catch (_) {
      // 忽略重复移除导致的异常
    } finally {
      _overlayEntry = null;
      _isShowing = false;
    }
  }

  static void _showToast(
    BuildContext context, {
    required String message,
    required bool? isSuccess, // null表示loading
    Duration? duration,
  }) {
    // 如果有正在显示的toast，先隐藏
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isSuccess: isSuccess,
        onDismiss: hide,
      ),
    );

    _isShowing = true;
    Overlay.of(context).insert(_overlayEntry!);

    // 自动隐藏
    if (duration != null) {
      Future.delayed(duration, () {
        hide();
      });
    }
  }

  /// 居中深色提示（半透明黑底、白字、10px 圆角，尺寸随文本自适应）
  static void showCenterDark(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    hide();
    _overlayEntry = OverlayEntry(
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.2),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(duration, hide);
  }
}

/// Toast组件实现
class _ToastWidget extends StatefulWidget {
  final String message;
  final bool? isSuccess; // null表示loading
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 10 + _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isDesktop ? 10 : 14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: mediaQuery.size.width - 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(isDesktop ? 10 : 14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIcon(desktop: isDesktop),
                          const SizedBox(width: 12),
                          Flexible(
                          child: Text(
                            widget.message,
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon({bool desktop = false}) {
    if (widget.isSuccess == null) {
      // Loading状态：统一使用 Link Me 动画（紧凑版）
      return const SizedBox(
        width: 26,
        height: 18,
        child: Center(
          child: LinkMeLoader(fontSize: 12, compact: true),
        ),
      );
    } else if (widget.isSuccess!) {
      // 成功状态 - 绿色勾勾
      final Color color = desktop ? const Color(0xFF10B981) : const Color(0xFF10B981);
      return Icon(Icons.check_circle, color: color, size: 20);
    } else {
      // 失败状态 - 红色叉叉
      final Color color = desktop ? const Color(0xFFEF4444) : const Color(0xFFEF4444);
      return Icon(Icons.error, color: color, size: 20);
    }
  }
}

/// Toast扩展方法，便于在任何地方调用
extension ToastExtension on BuildContext {
  /// 显示成功提示
  void showSuccessToast(String message, {Duration? duration}) {
    UnifiedToast.showSuccess(
      this, 
      message, 
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// 居中深色提示（半透明黑底、白字、10px 圆角）
  void showCenterDarkToast(String message, {Duration? duration}) {
    UnifiedToast.showCenterDark(this, message, duration: duration ?? const Duration(seconds: 2));
  }

  /// 显示错误提示
  void showErrorToast(String message, {Duration? duration}) {
    UnifiedToast.showError(
      this, 
      message, 
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// 显示加载提示
  void showLoadingToast(String message) {
    UnifiedToast.showLoading(this, message);
  }

  /// 显示信息提示（使用成功样式）
  void showInfoToast(String message, {Duration? duration}) {
    UnifiedToast.showSuccess(
      this, 
      message, 
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// 显示警告提示（使用错误样式）
  void showWarningToast(String message, {Duration? duration}) {
    UnifiedToast.showError(
      this, 
      message, 
      duration: duration ?? const Duration(seconds: 2),
    );
  }

  /// 隐藏提示
  void hideToast() {
    UnifiedToast.hide();
  }
}

/// 便捷的全局访问方法
class Toast {
  /// 显示成功提示
  static void success(BuildContext context, String message) {
    context.showSuccessToast(message);
  }

  /// 显示错误提示
  static void error(BuildContext context, String message) {
    context.showErrorToast(message);
  }

  /// 显示加载提示
  static void loading(BuildContext context, String message) {
    context.showLoadingToast(message);
  }

  /// 隐藏提示
  static void hide() {
    UnifiedToast.hide();
  }
}
