import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// custom_toast.dart | CustomToast | 自定义Toast提示
/// 在屏幕中央显示带图标和文本的提示，黑色半透明背景，白色图标和文字
class CustomToast {
  static OverlayEntry? _currentToast;

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: 'assets/app_icons/svg/tick-circle.svg',
    );
  }

  /// 显示错误提示
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: 'assets/app_icons/svg/danger.svg',
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: 'assets/app_icons/svg/info-circle.svg',
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: 'assets/app_icons/svg/info-circle.svg',
    );
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: null, // 加载使用 CircularProgressIndicator
      isLoading: true,
      duration: null, // 加载提示不自动消失
    );
  }

  /// 隐藏当前提示
  static void hide() {
    _currentToast?.remove();
    _currentToast = null;
  }

  /// 通用显示方法
  static void _show(
    BuildContext context, {
    required String message,
    String? icon,
    bool isLoading = false,
    Duration? duration = const Duration(seconds: 2),
  }) {
    // 移除之前的 Toast
    hide();

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        isLoading: isLoading,
      ),
    );

    _currentToast = overlayEntry;
    overlay.insert(overlayEntry);

    // 自动隐藏
    if (duration != null) {
      Future.delayed(duration, () {
        if (_currentToast == overlayEntry) {
          hide();
        }
      });
    }
  }
}

/// Toast 显示组件
class _ToastWidget extends StatefulWidget {
  final String message;
  final String? icon;
  final bool isLoading;

  const _ToastWidget({
    required this.message,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 120,
              maxWidth: 280,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标或加载指示器
                if (widget.isLoading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (widget.icon != null)
                  SvgPicture.asset(
                    widget.icon!,
                    width: 32,
                    height: 32,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                const SizedBox(height: 12),
                // 文本
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
