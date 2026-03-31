import 'package:linkme_flutter/core/theme/linkme_material.dart';
import '../../core/theme/app_colors.dart';

/// A tiny red badge used to show unread counters.
/// - Caps at 99+ to avoid layout explosion.
/// - When `count <= 0`, it renders nothing.
class UnreadBadge extends StatelessWidget {
  final int count;
  final double minSize;
  final Color? color;

  const UnreadBadge({
    super.key,
    required this.count,
    this.minSize = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final display = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      decoration: BoxDecoration(
        color: color ?? AppColors.error, // red badge
        borderRadius: BorderRadius.circular(minSize / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textWhite,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}

