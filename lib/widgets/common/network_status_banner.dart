import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:provider/provider.dart';

import '../../core/network/network_manager.dart';
import '../../core/network/server_health.dart';
import '../../features/chat/network_issue_page.dart';
import '../../core/theme/app_colors.dart';

/// QQ 风格网络/后端状态提示条
/// - 无网络/服务器异常：统一使用置顶卡片背景色
/// - 点击“查看原因/解决方案”跳转详情页
class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  late StreamSubscription _netSub;
  late StreamSubscription _serverSub;

  NetworkStatus _net = NetworkStatus.unknown;
  ServerStatus _server = ServerStatus.healthy;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    // 订阅网络与服务器状态
    final nm = NetworkManager();
    nm.initialize();
    _net = nm.networkStatus;
    _netSub = nm.networkStatusStream.listen((s) {
      if (!mounted) return;
      // 状态变化时重置关闭状态
      setState(() {
        _net = s;
        _isDismissed = false;
      });
    });
    final sh = ServerHealth();
    _server = sh.status;
    _serverSub = sh.stream.listen((s) {
      if (!mounted) return;
      setState(() {
        _server = s;
        _isDismissed = false;
      });
    });
  }

  @override
  void dispose() {
    _netSub.cancel();
    _serverSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(_isDismissed) return const SizedBox.shrink();

    // 统一背景色：置顶会话背景色 (primaryLight with 0.12 opacity)
    // 注意：AppColors.primaryLight 需要确保非空，这里假设 AppColors 可用
    final pinnedColor = AppColors.primaryLight.withOpacity(0.12);
    final foregroundColor = AppColors.textPrimary; // 浅色背景用深色字

    // 优先显示无网络
    if (_net == NetworkStatus.offline) {
      return _buildBanner(
        background: pinnedColor,
        foreground: foregroundColor,
        icon: Icons.wifi_off_rounded,
        text: '当前无网络，刷新失败！',
        actionText: '查看解决方案',
        issueType: NetworkIssueType.noNetwork,
      );
    }

    // 服务器异常（在在线状态下）
    if (_net == NetworkStatus.online && _server == ServerStatus.error) {
      return _buildBanner(
        background: pinnedColor,
        foreground: foregroundColor,
        icon: Icons.link_off_rounded,
        text: '服务器异常！',
        actionText: '查看原因',
        issueType: NetworkIssueType.serverError,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required Color background,
    required Color foreground,
    required IconData icon,
    required String text,
    required String actionText,
    required NetworkIssueType issueType,
  }) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: foreground, fontSize: 13),
                children: [
                   TextSpan(text: text),
                   const TextSpan(text: ' '), // spacer
                   TextSpan(
                     text: actionText,
                     style: const TextStyle(
                       color: AppColors.primary,
                       fontWeight: FontWeight.w600,
                       decoration: TextDecoration.underline,
                     ),
                     recognizer: TapGestureRecognizer()
                       ..onTap = () {
                         Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (_) => NetworkIssuePage(type: issueType),
                           ),
                         );
                       },
                   ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _isDismissed = true);
            },
            child: SvgPicture.asset(
              'assets/app_icons/svg/close-circle.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(foreground.withOpacity(0.6), BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }
}
