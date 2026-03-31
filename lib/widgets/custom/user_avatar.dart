import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import '../common/linkme_loader.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool showOnlineStatus;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 50,
    this.showOnlineStatus = false,
    this.isOnline = false,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth > 0
              ? Border.all(
                  color: borderColor ?? AppColors.border,
                  width: borderWidth,
                )
              : null,
        ),
        child: Stack(
          children: [
            // 头像主体
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor ?? AppColors.primaryLight,
              ),
              child: ClipOval(
                child: _buildAvatarContent(),
              ),
            ),
            
            // 在线状态指示器
            if (showOnlineStatus)
              Positioned(
                right: size * 0.05,
                bottom: size * 0.05,
                child: Container(
                  width: size * 0.25,
                  height: size * 0.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? AppColors.online : AppColors.offline,
                    border: Border.all(
                      color: AppColors.background,
                      width: size * 0.04,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    // 检查imageUrl是否有效
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      final trimmedUrl = imageUrl!.trim();
      // 特殊占位符: 后端用于表示“按成员头像拼接”的群头像配置，不应当作图片路径加载
      if (trimmedUrl.startsWith('GROUP_AVATAR:')) {
        return _buildPlaceholder();
      }
      
      // 网络图片
      if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
        return Image.network(
          trimmedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ 头像加载失败: $trimmedUrl, 错误: $error');
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder();
          },
        );
      }
      // 本地图片路径
      else if (trimmedUrl.contains('.')) {
        return Image.asset(
          trimmedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ 本地头像加载失败: $trimmedUrl');
            return _buildPlaceholder();
          },
        );
      }
      // 其他情况，可能是无效的URL
      else {
        print('⚠️ 无效的头像URL: $trimmedUrl');
        return _buildPlaceholder();
      }
    } else {
      // 没有头像URL，使用默认占位符
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor ?? AppColors.primaryLight,
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.surface,
      child: Center(
        child: SizedBox(
          height: size * 0.26,
          child: LinkMeLoader(
            fontSize: (size * 0.18).clamp(10, 18).toDouble(),
            compact: true,
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) {
      return '?';
    }
    
    final words = name!.trim().split(' ');
    if (words.length >= 2) {
      return (words.first.isNotEmpty ? words.first[0] : '') +
          (words.last.isNotEmpty ? words.last[0] : '');
    } else {
      return name!.isNotEmpty ? name![0] : '?';
    }
  }
}
