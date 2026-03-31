import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/unified_toast.dart' as _toast show ToastExtension; // bring extension methods
import '../../widgets/common/in_app_browser.dart';

class UrlLauncherHelper {
  static Future<void> openUrl(
    BuildContext context,
    String url, {
    bool useInAppBrowser = true,
    String? title,
  }) async {
    if (!_isValidUrl(url)) {
      _showErrorMessage(context, '无效的URL地址');
      return;
    }

    final uri = Uri.parse(url);

    if (_isWebUrl(uri)) {
      if (useInAppBrowser) {
        await _openInAppBrowser(context, url, title);
      } else {
        await _openInExternalBrowser(uri, context);
      }
    } else {
      await _openInExternalApp(uri, context);
    }
  }

  // 新增：直接在应用内打开URL
  static Future<void> openUrlDirectly(
    BuildContext context,
    String url, {
    String? title,
  }) async {
    if (!_isValidUrl(url)) {
      _showErrorMessage(context, '无效的URL地址');
      return;
    }

    final uri = Uri.parse(url);

    if (_isWebUrl(uri)) {
      await _openInAppBrowser(context, url, title);
    } else {
      await _openInExternalApp(uri, context);
    }
  }

  static Future<void> _openInAppBrowser(
    BuildContext context,
    String url,
    String? title,
  ) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InAppBrowser(
            url: url,
            title: title,
          ),
        ),
      );
    } catch (e) {
      _showErrorMessage(context, '打开网页失败: $e');
    }
  }

  static Future<void> _openInExternalBrowser(Uri uri, BuildContext context) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorMessage(context, '无法打开外部浏览器');
      }
    } catch (e) {
      _showErrorMessage(context, '打开外部浏览器失败: $e');
    }
  }

  static Future<void> _openInExternalApp(Uri uri, BuildContext context) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorMessage(context, '无法打开此类型的链接');
      }
    } catch (e) {
      _showErrorMessage(context, '打开链接失败: $e');
    }
  }

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme;
    } catch (e) {
      return false;
    }
  }

  static bool _isWebUrl(Uri uri) {
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static void _showErrorMessage(BuildContext context, String message) {
    // 统一改为顶部提示，保持与全局 toast 一致
    // 使用我们封装的统一提示组件，避免底部 SnackBar 挡住输入框
    // ignore: use_build_context_synchronously
    context.showErrorToast(message);
  }

  static void showUrlActionDialog(
    BuildContext context,
    String url, {
    String? title,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              url,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openUrl(context, url, useInAppBrowser: false, title: title);
            },
            child: const Text('外部浏览器'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openUrl(context, url, useInAppBrowser: true, title: title);
            },
            child: const Text('应用内打开'),
          ),
        ],
      ),
    );
  }
}
