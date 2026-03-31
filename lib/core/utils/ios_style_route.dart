import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

/// GoRouter页面构建辅助函数
/// 使用 CupertinoPage 实现 iOS 风格的手势返回
Page<dynamic> buildIOSStylePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  bool enableSwipeBack = true,
}) {
  // 使用 CupertinoPage 实现手势返回
  // CupertinoPage 会自动处理从左边缘向右滑动的手势，页面从右向左退出
  return CupertinoPage(
    key: state.pageKey,
    child: child,
  );
}