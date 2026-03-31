import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知服务 - 管理应用徽章和本地通知
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 仅在Android平台初始化本地通知
      if (Platform.isAndroid) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const InitializationSettings initializationSettings =
            InitializationSettings(
          android: initializationSettingsAndroid,
        );

        await _flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // 请求通知权限（Android 13+）
        await requestPermission();

        if (kDebugMode) {
          print('✅ 通知服务初始化成功');
        }
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 通知服务初始化失败: $e');
      }
    }
  }

  /// 处理通知点击事件
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('📱 通知被点击: ${response.payload}');
    }
    // 可以在这里处理通知点击后的导航逻辑
  }

  /// 更新应用图标徽章数字
  /// 支持iOS和Android（部分Android启动器支持）
  Future<void> updateBadgeCount(int count) async {
    try {
      if (kDebugMode) {
        print('📱 尝试更新应用徽章数: $count');
      }

      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (kDebugMode) {
        print('📱 徽章支持状态: $isSupported');
      }

      if (!isSupported) {
        if (kDebugMode) {
          print('⚠️ 当前设备/启动器不支持应用徽章');
        }
        return;
      }

      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
        if (kDebugMode) {
          print('✅ 应用徽章已更新: $count');
        }
      } else {
        // 清除徽章
        await FlutterAppBadger.removeBadge();
        if (kDebugMode) {
          print('✅ 应用徽章已清除');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 更新应用徽章失败: $e');
        print('堆栈跟踪: ${StackTrace.current}');
      }
    }
  }

  /// 显示新消息通知（仅Android）
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'chat_messages', // 通道ID
        '聊天消息', // 通道名称
        channelDescription: '新聊天消息通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000, // 使用时间戳生成唯一ID
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      if (kDebugMode) {
        print('📬 已发送通知: $title - $body');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 发送通知失败: $e');
      }
    }
  }

  /// 清除所有通知
  Future<void> clearAllNotifications() async {
    if (!Platform.isAndroid) return;

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      if (kDebugMode) {
        print('🗑️ 已清除所有通知');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清除通知失败: $e');
      }
    }
  }

  /// 请求通知权限（Android 13+）
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final plugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (plugin != null) {
        final granted = await plugin.requestNotificationsPermission();
        if (kDebugMode) {
          print('🔔 通知权限请求结果: $granted');
        }
        return granted ?? false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 请求通知权限失败: $e');
      }
    }
    return false;
  }
}
