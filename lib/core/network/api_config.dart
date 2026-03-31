import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/app_constants.dart';

class ApiConfig {
  // 开发环境：默认使用 localhost，确保 macOS 桌面端与 iOS 模拟器可连；
  // Android 模拟器使用 10.0.2.2。可通过 --dart-define=IM_SERVER_HOST=192.168.x.x 覆盖。
  static String _devHost() {
    // 默认使用本机局域网IP（当前机器: 192.168.1.3）。
    // 如需变更，可通过 --dart-define=IM_SERVER_HOST=192.168.x.x 覆盖。
    const override =
        String.fromEnvironment('IM_SERVER_HOST', defaultValue: '192.168.1.3');
    if (override.isNotEmpty && override != 'localhost') return override;
    if (kIsWeb) return '192.168.1.3';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return '192.168.1.3';
  }

  static String get _devBaseUrl => '';
  static String get _devWsUrl => '#';
  static String get _devAcademyBaseUrl => '#';

  static const String _prodBaseUrl = '';
  static const String _prodWsUrl = '#';
  static const String _prodAcademyBaseUrl = '#';

  static const bool isProduction =
      bool.fromEnvironment('IM_USE_PRODUCTION', defaultValue: true);

  static String get baseUrl {
    final override =
        const String.fromEnvironment('IM_SERVER_BASE', defaultValue: '');
    if (override.trim().isNotEmpty) {
      return _attachApiPrefix(_trimTrailingSlash(override.trim()));
    }
    final manual = AppConstants.baseUrl.trim();
    if (manual.isNotEmpty) {
      return _attachApiPrefix(_trimTrailingSlash(manual));
    }
    return isProduction ? _prodBaseUrl : _devBaseUrl;
  }

  static String get wsUrl {
    final override =
        const String.fromEnvironment('IM_SERVER_WS', defaultValue: '');
    if (override.trim().isNotEmpty) {
      return _trimTrailingSlash(override.trim());
    }
    final manual = AppConstants.wsUrl.trim();
    if (manual.isNotEmpty) {
      return _trimTrailingSlash(manual);
    }
    final httpBase = baseUrl;
    return _httpToWs(_swapApiToWs(httpBase));
  }

  /// 学院服务baseUrl
  static String get academyBaseUrl {
    return isProduction ? _prodAcademyBaseUrl : _devAcademyBaseUrl;
  }

  static String _attachApiPrefix(String base) {
    if (base.endsWith(AppConstants.apiPrefix)) return base;
    return '$base${AppConstants.apiPrefix}';
  }

  static String _swapApiToWs(String httpUrl) {
    if (httpUrl.contains(AppConstants.apiPrefix)) {
      return httpUrl.replaceFirst(
          AppConstants.apiPrefix, '/ws-native'); // 默认WebSocket路径
    }
    return '$httpUrl/ws-native';
  }

  static String _trimTrailingSlash(String input) {
    if (input.endsWith('/')) {
      return input.substring(0, input.length - 1);
    }
    return input;
  }

  static String _httpToWs(String httpUrl) {
    if (httpUrl.startsWith('https')) {
      return httpUrl.replaceFirst('https', 'wss');
    }
    if (httpUrl.startsWith('http')) {
      return httpUrl.replaceFirst('http', 'ws');
    }
    return httpUrl;
  }

  // API端点
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String emailRequestCode = '/auth/email/request-code';
  static const String emailRegister = '/auth/email/register';
  static const String emailLogin = '/auth/email/login';
  static const String completeProfile = '/users/profile/complete';
  static const String passwordSetup = '/users/password/setup';
  // 用户相关API
  // 注意: 后端Controller映射为 @RequestMapping("/api/users"),
  // 因此前缀必须是 "/users" 而不是 "/user"。
  // 之前这里写成了 "/user/profile" 导致 404，
  // 使得 Flutter 端无法更新昵称/签名。
  static const String userProfile = '/users/profile'; // 当前用户个人资料
  static const String users = '/users'; // 获取其他用户信息
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String messages = '/messages';
  static const String groups = '/groups';
  static const String favorites = '/favorites';
  static const String quickLinks = '/quick-links';
  static const String emotion = '/emotion';
  static const String accountDeletion = '/users/account/deletion';
  static const String uploadAvatar = '/users/avatar/upload'; // 头像上传
  static const String uploadChatImage = '/messages/image/upload'; // 聊天图片上传

  // 超时配置
  static const int connectTimeout = 10000; // 10秒
  static const int receiveTimeout = 10000; // 10秒
  static const int sendTimeout = 10000; // 10秒

  // WebSocket配置
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 5;
}
