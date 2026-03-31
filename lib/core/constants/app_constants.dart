class AppConstants {
  // App Info
  static const String appName = 'LinkMe';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  // 默认指向当前线上服务，配置请求地址
  static const String baseUrl = 'http://43.251.227.214:8080';
  static const String apiPrefix = '/api';
  static const String wsUrl = '';
  
  // Storage Keys
  static const String tokenKey = 'token';
  static const String userKey = 'user';
  static const String themeKey = 'theme';
  
  // Animation Durations
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  static const double defaultRadius = 12.0;
  static const double smallRadius = 8.0;
  static const double largeRadius = 16.0;
  
  // WebSocket
  static const Duration heartbeatInterval = Duration(seconds: 25);
  static const Duration reconnectDelay = Duration(seconds: 3);
}
