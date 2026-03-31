import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:intl/intl.dart';
import '../../shared/models/favorite.dart';
import 'user_avatar.dart';
import '../common/linkable_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/models/favorite.dart';

class FavoriteDisplay extends StatelessWidget {
  final Favorite favorite;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const FavoriteDisplay({
    super.key,
    required this.favorite,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final senderName = favorite.senderName ?? favorite.title ?? '收藏内容';
    final senderAvatar = favorite.senderAvatar ?? favorite.conversationAvatar;
    final timestamp = favorite.messageTimestamp;
    final dateText = timestamp != null ? DateFormat('yyyy/MM/dd HH:mm').format(timestamp) : null;
    final conversationName = favorite.conversationName;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  imageUrl: senderAvatar,
                  name: senderName,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: AppTextStyles.friendName.copyWith(fontSize: 15),
                      ),
                      if (dateText != null)
                        Text(
                          dateText,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (conversationName != null && conversationName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    favorite.isGroupConversation ? Icons.groups_outlined : Icons.person_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      conversationName,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (favorite.type) {
      case FavoriteType.link:
        final linkUrl = favorite.linkUrl ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              favorite.title ?? favorite.content,
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            if (favorite.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                favorite.description!,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (linkUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                linkUrl,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        );
      case FavoriteType.text:
      case FavoriteType.message:
      default:
        return LinkableText(
          favorite.content,
          style: AppTextStyles.body2.copyWith(color: AppColors.textPrimary),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}
