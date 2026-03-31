import 'package:linkme_flutter/core/theme/linkme_material.dart';

class AppColors {
  // Primary Colors - 基于 Web 端的粉色主题
  static const Color primary = Color(0xFFFF6B9D); // #ff6b9d
  static const Color primaryLight = Color(0xFFFFB3D1); // #ffb3d1
  static const Color primaryDark = Color(0xFFE55A87); // #e55a87
  
  // Secondary Colors
  static const Color secondary = Color(0xFF9C27B0); // 紫色
  static const Color secondaryLight = Color(0xFFCE93D8);
  static const Color secondaryDark = Color(0xFF7B1FA2);
  
  // Background Colors
  static const Color background = Color(0xFFFFFFFF); // 白色背景
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  
  // Glass Effect
  static const Color glassBackground = Color(0xCCFFFFFF); // rgba(255, 255, 255, 0.8)
  
  // Text Colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000); // rgba(0, 0, 0, 0.1)
  static const Color shadowMedium = Color(0x26000000); // rgba(0, 0, 0, 0.15)
  static const Color shadowHeavy = Color(0x33000000); // rgba(0, 0, 0, 0.2)
  
  // Online Status
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  
  // Message Colors
  static const Color myMessageBg = primary;
  static const Color otherMessageBg = Color(0xFFF5F5F5);
  static const Color pinnedMessageBg = Color(0xFFF9FAFB);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFBFE), background],
  );

  // Orange → Red gradient for highlights (e.g., 热点图标)
  static const LinearGradient hotGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF7A00), // vivid orange
      Color(0xFFFF3D00), // red-orange
    ],
  );

  // Desktop-specific soft background gradient (light pink x light beige)
  // Used to mimic a gentle, interwoven background on desktop auth screens
  static const LinearGradient desktopSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFEEF3), // very light pink
      Color(0xFFFFF3E6), // light beige
      Color(0xFFFFE6F0), // soft pink accent
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );
}
