import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'linkme_loader.dart';

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final double? height;

  const EmptyState({
    super.key,
    this.icon,
    this.imagePath,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.height,
  });

  // 预设的空状态样式
  const EmptyState.noConversations({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.chat_bubble_outline,
        imagePath = null,
        title = '暂无聊天',
        subtitle = '开始与朋友聊天吧',
        buttonText = '添加好友';

  const EmptyState.noFriends({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.people_outline,
        imagePath = null,
        title = '暂无好友',
        subtitle = '添加好友开始聊天',
        buttonText = '添加好友';

  const EmptyState.noMessages({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.message_outlined,
        imagePath = null,
        title = '暂无消息',
        subtitle = '发送第一条消息开始对话',
        buttonText = null;

  const EmptyState.noSearchResults({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.search_off,
        imagePath = null,
        title = '暂无搜索结果',
        subtitle = '尝试使用其他关键词',
        buttonText = null;

  const EmptyState.noFavorites({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.favorite_border,
        imagePath = null,
        title = '暂无收藏',
        subtitle = '收藏重要的消息和文件',
        buttonText = null;

  const EmptyState.networkError({
    super.key,
    this.onButtonPressed,
    this.height,
  })  : icon = Icons.wifi_off,
        imagePath = null,
        title = '网络连接失败',
        subtitle = '请检查网络设置后重试',
        buttonText = '重试';

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.h5.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: AppTextStyles.body2.copyWith(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
          if (buttonText != null && onButtonPressed != null) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(buttonText!),
            ),
          ],
        ],
      ),
    );

    Widget builder = LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = height ?? constraints.maxHeight;
        final hasFiniteHeight =
            availableHeight.isFinite && availableHeight > 0;
        final shouldScroll =
            hasFiniteHeight && availableHeight < 360; // keyboard 等小高度

        Widget child = Center(child: content);
        if (hasFiniteHeight) {
          child = ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: child,
          );
        }

        return SingleChildScrollView(
          physics: shouldScroll
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: child,
        );
      },
    );

    if (height != null) {
      builder = SizedBox(height: height, child: builder);
    }
    return builder;
  }

  Widget _buildIcon() {
    if (imagePath != null) {
      return Image.asset(
        imagePath!,
        width: 120,
        height: 120,
        color: AppColors.textLight,
      );
    } else if (icon != null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(60),
        ),
        child: Icon(
          icon,
          size: 60,
          color: AppColors.textLight,
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

// 加载状态组件
class LoadingState extends StatelessWidget {
  final String? message;
  final double? height;

  const LoadingState({
    super.key,
    this.message,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Unified Link Me loading animation (smaller size per spec)
          const SizedBox(height: 2),
          const _LoadingLogo(),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// Small wrapper to show the unified loader in LoadingState
class _LoadingLogo extends StatelessWidget {
  const _LoadingLogo();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: Center(child: LinkMeLoader(fontSize: 20)),
    );
  }
}

// 错误状态组件
class ErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final String? buttonText;
  final VoidCallback? onRetry;
  final double? height;

  const ErrorState({
    super.key,
    this.title,
    this.message,
    this.buttonText,
    this.onRetry,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.error,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            title ?? '出错了',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          if (buttonText != null && onRetry != null) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(buttonText!),
            ),
          ],
        ],
      ),
    );
  }
}
