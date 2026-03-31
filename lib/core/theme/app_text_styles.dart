import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Font Family - 使用系统默认字体
  static const String fontFamily = 'PingFang SC'; // iOS 系统自带字体
  
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle h6 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  // Body Text
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.6,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.6,
  );
  
  // Small Text
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    color: AppColors.textLight,
    height: 1.6,
    letterSpacing: 0.5,
  );
  
  // Button Text
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    height: 1.2,
    letterSpacing: 0.1,
  );
  
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    height: 1.2,
    letterSpacing: 0.1,
  );
  
  // Chat Specific
  static const TextStyle friendName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  static const TextStyle friendStatus = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    height: 1.2,
  );
  
  static const TextStyle messageContent = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle messageTime = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textLight,
    height: 1.2,
  );
  
  // Input Text
  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle inputHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    color: AppColors.textLight,
    height: 1.4,
  );
  
  // Navbar
  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
    height: 1.2,
  );
}