library linkme_material;

import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as material show Icon;
import 'package:flutter_svg/flutter_svg.dart';

export 'package:flutter/material.dart' hide Icon;

/// linkme_material.dart | Icon | constructor | icon,size,color
class Icon extends StatelessWidget {
  const Icon(
    this.icon, {
    super.key,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
  });

  final IconData? icon;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;

  /// linkme_material.dart | Icon | build | icon,size,color
  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedIcon = icon ?? Icons.help_outline;
    final resolvedSize = size ?? iconTheme.size ?? 24.0;
    final double opacity = iconTheme.opacity ?? 1.0;
    final Color? resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    final Color? effectiveColor =
        resolvedColor?.withOpacity(resolvedColor.opacity * opacity);

    // Whenever advanced typography knobs are used, keep Material's original Icon.
    if ((shadows != null && shadows!.isNotEmpty) ||
        fill != null ||
        weight != null ||
        grade != null ||
        opticalSize != null) {
      return material.Icon(
        resolvedIcon,
        size: resolvedSize,
        color: effectiveColor,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
        shadows: shadows,
        fill: fill,
        weight: weight,
        grade: grade,
        opticalSize: opticalSize,
      );
    }

    final assetPath = _LinkMeIconRegistry.pathFor(resolvedIcon);
    if (assetPath == null) {
      return material.Icon(
        resolvedIcon,
        size: resolvedSize,
        color: effectiveColor,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      );
    }

    final displayedDirection =
        textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: displayedDirection,
      child: SvgPicture.asset(
        assetPath,
        width: resolvedSize,
        height: resolvedSize,
        colorFilter: effectiveColor != null
            ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
            : null,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}

/// linkme_material.dart | _LinkMeIconRegistry | class | icon mapping cache
class _LinkMeIconRegistry {
  static const String _base = 'assets/app_icons/svg';

  static final Map<IconData, String> _iconMap = <IconData, String>{
    Icons.access_time: 'clock.svg',
    Icons.account_balance: 'bank.svg',
    Icons.account_balance_wallet: 'wallet.svg',
    Icons.add: 'add.svg',
    Icons.add_circle_outline: 'add-circle.svg',
    Icons.arrow_back: 'arrow-left.svg',
    Icons.arrow_back_ios: 'arrow-left-1.svg',
    Icons.arrow_back_ios_new: 'arrow-left-2.svg',
    Icons.arrow_back_ios_new_rounded: 'arrow-left-3.svg',
    Icons.arrow_forward_ios: 'arrow-right-1.svg',
    Icons.arrow_upward: 'arrow-up.svg',
    Icons.article_outlined: 'document-text.svg',
    Icons.badge_outlined: 'medal.svg',
    Icons.block: 'shield-cross.svg',
    Icons.bookmark_border: 'bookmark.svg',
    Icons.bookmark_border_rounded: 'bookmark-2.svg',
    Icons.broken_image: 'gallery-slash.svg',
    Icons.camera_alt: 'camera.svg',
    Icons.camera_alt_outlined: 'camera-slash.svg',
    Icons.campaign: 'speaker.svg',
    Icons.cancel: 'close-circle.svg',
    Icons.category_outlined: 'category.svg',
    Icons.chat_bubble: 'message.svg',
    Icons.chat_bubble_outline: 'message-circle.svg',
    Icons.chat_bubble_rounded: 'message-square.svg',
    Icons.check_circle: 'tick-circle.svg',
    Icons.chevron_right: 'arrow-right.svg',
    Icons.circle: 'record-circle.svg',
    Icons.clear: 'close-square.svg',
    Icons.close: 'close-circle.svg',
    Icons.content_copy: 'copy.svg',
    Icons.copy: 'copy.svg',
    Icons.copy_all_rounded: 'copy-success.svg',
    Icons.credit_card: 'card.svg',
    Icons.credit_card_off: 'card-remove.svg',
    Icons.delete: 'trash.svg',
    Icons.delete_forever: 'trash.svg',
    Icons.delete_outline: 'trash.svg',
    Icons.delete_outline_rounded: 'trash.svg',
    Icons.description: 'document-text.svg',
    Icons.description_outlined: 'document-text.svg',
    Icons.do_not_disturb: 'slash.svg',
    Icons.double_arrow_rounded: 'arrow-2.svg',
    Icons.download: 'download.svg',
    Icons.edit: 'edit.svg',
    Icons.edit_note_outlined: 'edit.svg',
    Icons.edit_outlined: 'edit.svg',
    Icons.email_outlined: 'sms.svg',
    Icons.emoji_emotions_outlined: 'emoji-happy.svg',
    Icons.error: 'danger.svg',
    Icons.error_outline: 'warning-2.svg',
    Icons.error_rounded: 'warning-2.svg',
    Icons.exit_to_app: 'logout-1.svg',
    Icons.expand_more: 'arrow-down-1.svg',
    Icons.favorite: 'heart.svg',
    Icons.favorite_border: 'heart-circle.svg',
    Icons.favorite_outline: 'heart-circle.svg',
    Icons.flag_outlined: 'flag.svg',
    Icons.grid_view_outlined: 'grid-1.svg',
    Icons.grid_view_rounded: 'grid-1.svg',
    Icons.group: 'profile-2user.svg',
    Icons.group_add: 'user-add.svg',
    Icons.group_outlined: 'profile-2user.svg',
    Icons.groups_outlined: 'profile-2user.svg',
    Icons.headset_mic_outlined: 'headphones.svg',
    Icons.home: 'home-2.svg',
    Icons.hub_outlined: 'hierarchy.svg',
    Icons.image: 'gallery.svg',
    Icons.image_not_supported: 'gallery-slash.svg',
    Icons.image_not_supported_outlined: 'gallery-slash.svg',
    Icons.image_outlined: 'gallery.svg',
    Icons.info_outline: 'info-circle.svg',
    Icons.inventory_2_outlined: 'box.svg',
    Icons.ios_share: 'share.svg',
    Icons.keyboard: 'keyboard.svg',
    Icons.keyboard_arrow_down: 'arrow-down-2.svg',
    Icons.keyboard_arrow_up: 'arrow-up-2.svg',
    Icons.language: 'language-circle.svg',
    Icons.lightbulb_outline: 'lamp-on.svg',
    Icons.link: 'link.svg',
    Icons.link_off: 'link-2.svg',
    Icons.link_off_rounded: 'link-2.svg',
    Icons.link_outlined: 'link.svg',
    Icons.local_fire_department: 'sun.svg',
    Icons.local_offer: 'tag.svg',
    Icons.local_shipping_outlined: 'truck-tick.svg',
    Icons.location_on: 'location.svg',
    Icons.lock_outline: 'lock.svg',
    Icons.logout: 'logout.svg',
    Icons.mail_outline: 'sms.svg',
    Icons.mark_email_read_outlined: 'sms-notification.svg',
    Icons.mark_email_unread_outlined: 'sms-tracking.svg',
    Icons.message_outlined: 'message-text.svg',
    Icons.mic: 'microphone.svg',
    Icons.mic_none_outlined: 'microphone-slash.svg',
    Icons.mode_comment_outlined: 'messages-1.svg',
    Icons.more_horiz: 'more.svg',
    Icons.more_horiz_rounded: 'more-2.svg',
    Icons.more_vert: 'more-square.svg',
    Icons.notifications: 'notification.svg',
    Icons.notifications_outlined: 'notification-1.svg',
    Icons.payment: 'card.svg',
    Icons.people: 'people.svg',
    Icons.people_outline: 'people.svg',
    Icons.person: 'profile.svg',
    Icons.person_add: 'user-add.svg',
    Icons.person_add_alt: 'user-add.svg',
    Icons.person_off_outlined: 'profile-remove.svg',
    Icons.person_outline: 'profile-circle.svg',
    Icons.person_remove: 'user-minus.svg',
    Icons.person_search: 'user-search.svg',
    Icons.phone: 'call.svg',
    Icons.phone_iphone: 'mobile.svg',
    Icons.photo_camera: 'camera.svg',
    Icons.photo_camera_outlined: 'camera-slash.svg',
    Icons.photo_library: 'gallery.svg',
    Icons.photo_library_outlined: 'gallery-add.svg',
    Icons.privacy_tip_outlined: 'shield-security.svg',
    Icons.push_pin: 'note-add.svg',
    Icons.push_pin_outlined: 'note-add.svg',
    Icons.receipt_long_outlined: 'receipt.svg',
    Icons.remove_circle_outline: 'minus-cirlce.svg',
    Icons.reply: 'direct-left.svg',
    Icons.reply_outlined: 'direct-left.svg',
    Icons.reply_rounded: 'direct-left.svg',
    Icons.report_outlined: 'warning-2.svg',
    Icons.rule_folder_outlined: 'folder.svg',
    Icons.schedule_rounded: 'timer.svg',
    Icons.search: 'search-normal.svg',
    Icons.search_off: 'search-status-1.svg',
    Icons.send: 'send.svg',
    Icons.send_outlined: 'send-1.svg',
    Icons.settings_outlined: 'setting.svg',
    Icons.share_outlined: 'share.svg',
    Icons.shield_moon_outlined: 'shield.svg',
    Icons.shield_outlined: 'shield.svg',
    Icons.shopping_bag: 'shopping-bag.svg',
    Icons.shopping_bag_outlined: 'shopping-bag.svg',
    Icons.shopping_cart: 'shopping-cart.svg',
    Icons.shopping_cart_outlined: 'shopping-cart.svg',
    Icons.star: 'star.svg',
    Icons.star_border: 'star-1.svg',
    Icons.star_border_rounded: 'star-1.svg',
    Icons.star_outline: 'star-1.svg',
    Icons.star_rounded: 'star.svg',
    Icons.storage: 'strongbox.svg',
    Icons.storefront: 'shop.svg',
    Icons.storefront_outlined: 'shop.svg',
    Icons.swap_horiz: 'arrow-swap-horizontal.svg',
    Icons.text_fields: 'text.svg',
    Icons.undo: 'undo.svg',
    Icons.undo_rounded: 'undo.svg',
    Icons.verified: 'verify.svg',
    Icons.verified_outlined: 'verify.svg',
    Icons.verified_user_outlined: 'security-user.svg',
    Icons.vibration: 'alarm.svg',
    Icons.videocam: 'video.svg',
    Icons.visibility_off_outlined: 'eye-slash.svg',
    Icons.visibility_outlined: 'eye.svg',
    Icons.volume_off: 'volume-mute.svg',
    Icons.volume_up: 'volume-up.svg',
    Icons.volume_up_outlined: 'volume-up.svg',
    Icons.warning_amber_rounded: 'warning-2.svg',
    Icons.wifi_off: 'wifi-square.svg',
    Icons.wifi_off_rounded: 'wifi-square.svg',
    Icons.workspace_premium: 'award.svg',
    Icons.workspace_premium_outlined: 'award.svg',
  };

  /// linkme_material.dart | _LinkMeIconRegistry | pathFor | iconData
  static String? pathFor(IconData? iconData) {
    if (iconData == null) return null;
    final relative = _iconMap[iconData];
    if (relative == null) {
      return null;
    }
    return '$_base/$relative';
  }
}
