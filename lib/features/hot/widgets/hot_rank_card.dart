import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'dart:math' show min;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class HotItem {
  final String title;
  final String? summary;
  final int heat;
  final int shops; // 0 代表非门店类
  final bool promo;
  final IconData icon; // 先用系统 icon 占位（加载失败时回退）
  final String? imageUrl; // 品牌/相关网络图片
  final int? articleId; // 关联文章ID（点击进入详情）
  const HotItem({
    required this.title,
    this.summary,
    required this.heat,
    required this.shops,
    required this.promo,
    required this.icon,
    this.imageUrl,
    this.articleId,
  });
}

class HotRankCard extends StatelessWidget {
  final WidgetBuilder titleBuilder; // 头部行（含火焰、标题、查看全部）
  final List<HotItem> items;
  final double scale; // 紧凑比例（1.0 为原始大小）
  final void Function(HotItem item)? onItemTap;

  const HotRankCard({super.key, required this.titleBuilder, required this.items, this.scale = 1.0, this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final s = scale.clamp(0.4, 1.2);
    final borderWidth = 1.0 / MediaQuery.of(context).devicePixelRatio; // 极细边
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: const Color(0xFFFFE3D6), width: borderWidth), // 浅橙色超细边
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16 * s, offset: Offset(0, 6 * s))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16 * s),
        child: CustomPaint(
          painter: _HeaderGlowPainter(scale: s),
          child: Padding(
            // 顶部保留舒适空间10px，底部仅5px以贴近设计（按比例缩放）
            padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 5 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 高度由内容决定，避免底部大留白
              children: [
                Builder(builder: titleBuilder),
                SizedBox(height: 8 * s),
                if (items.isEmpty)
                  SizedBox(
                    height: 160 * s,
                    child: const Center(child: Text('暂无热点内容', style: TextStyle(color: AppColors.textLight))),
                  )
                else
                  ...List.generate(
                    min(10, items.length),
                    (i) => _HotRow(
                      index: i + 1,
                      item: items[i],
                      isLast: i == min(10, items.length) - 1,
                      topSpacing: 8 * s,
                      bottomSpacing: 0,
                      scale: s,
                      onTap: onItemTap,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotRow extends StatelessWidget {
  final int index;
  final HotItem item;
  final bool isLast;
  final double topSpacing;
  final double bottomSpacing; // when last row, this can be 0 to keep only card padding
  final double scale;
  final void Function(HotItem item)? onTap;
  const _HotRow({
    required this.index,
    required this.item,
    this.isLast = false,
    this.topSpacing = 8,
    this.bottomSpacing = 8,
    this.scale = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary;
    final s = scale.clamp(0.4, 1.2);
    final content = Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: isLast ? bottomSpacing : topSpacing),
      child: Row(
        children: [
          // 占位图片：用系统 icon + 轻微圆角
          ClipRRect(
            borderRadius: BorderRadius.circular(8 * s),
            child: Stack(
              children: [
                SizedBox(
                  width: 48 * s,
                  height: 48 * s,
                  child: item.imageUrl == null
                      ? Container(color: Colors.white.withOpacity(0.9), alignment: Alignment.center, child: Icon(item.icon, color: Colors.black54))
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.white.withOpacity(0.9), alignment: Alignment.center, child: Icon(item.icon, color: Colors.black54)),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(color: Colors.white.withOpacity(0.9), alignment: Alignment.center, child: Icon(item.icon, color: Colors.black54));
                          },
                        ),
                ),
                Positioned(
                  left: 4 * s,
                  top: 4 * s,
                  child: _RankBadge(index: index, compact: true),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题：单行省略
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2 * s),
                // 概要 + 热度：同一行。概要不足一行时，右侧显示热度徽标；
                // 若无概要，仅显示右侧热度。
                Builder(builder: (context) {
                  final summary = item.summary?.trim() ?? '';
                  final heatBadge = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, size: 14, color: Color(0xFFFF7A00)),
                      const SizedBox(width: 2),
                      Text(_formatHeat(item.heat), style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
                    ],
                  );
                  if (summary.isNotEmpty) {
                    return Row(
                      children: [
                        Expanded(child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
                        const SizedBox(width: 8),
                        heatBadge,
                      ],
                    );
                  }
                  return Align(alignment: Alignment.centerRight, child: heatBadge);
                }),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: () => onTap!(item), child: content);
    }
    return content;
  }

  static String _formatHeat(int v) => v.toString();
  static String _shopLine(int shops) => shops > 0 ? '$shops 个门店正在热卖' : '点外卖赢 iPhone';
}

class _PromoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFFF4848), borderRadius: BorderRadius.circular(4)),
      child: const Text('促', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1)),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int index;
  final bool compact; // 图片内角标更紧凑
  const _RankBadge({required this.index, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final Gradient g;
    Color textColor = Colors.white;
    switch (index) {
      case 1:
        g = AppColors.hotGradient;
        break;
      case 2:
        g = const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFC107)]);
        textColor = const Color(0xFF7A4E00);
        break;
      case 3:
        g = const LinearGradient(colors: [Color(0xFF90CAF9), Color(0xFF42A5F5)]);
        break;
      default:
        g = const LinearGradient(colors: [Color(0xFFEDEDED), Color(0xFFD8D8D8)]);
        textColor = const Color(0xFF666666);
    }

    final double h = compact ? 18 : 22;
    final double w = compact ? 18 : 22;
    final double r = h / 2;

    return CustomPaint(
      painter: _BadgePainter(gradient: g, radius: r),
      child: SizedBox(
        width: w,
        height: h,
        child: Center(
          child: Text('$index', style: TextStyle(color: textColor, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w700, height: 1)),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  final Gradient gradient;
  final double radius;
  const _BadgePainter({required this.gradient, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topLeft: r, topRight: r, bottomRight: r, bottomLeft: r,
    );
    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) => false;
}

/// 顶部“融合光晕”效果的简化版，用作预览。
/// 后续可替换为设计给的透明 PNG/SVG 覆盖层。
class _HeaderGlowPainter extends CustomPainter {
  final double scale;
  const _HeaderGlowPainter({this.scale = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    // 仅在顶部区域绘制融合渐变，中下部保持极淡底色
    final s = scale.clamp(0.4, 1.2);
    final topH = 120.0 * s;
    final topRect = Rect.fromLTWH(0, 0, size.width, topH);

    // 左上暖色光斑
    final lg1 = RadialGradient(
      colors: const [Color(0xFFFFE1CF), Color(0x00FFE1CF)],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(60 * s, 20 * s), radius: 120 * s));
    canvas.save();
    canvas.clipRect(topRect);
    canvas.drawRect(topRect, Paint()..shader = lg1);

    // 右上粉白流光
    final lg2 = RadialGradient(
      colors: const [Color(0xFFFFF1F7), Color(0x00FFF1F7)],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(size.width - 30 * s, 0), radius: 140 * s));
    canvas.drawRect(topRect, Paint()..shader = lg2);

    // 右上角一点高光
    final lg3 = RadialGradient(
      colors: const [Colors.white70, Colors.transparent],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(size.width - 60 * s, 10 * s), radius: 80 * s));
    canvas.drawRect(topRect, Paint()..shader = lg3);
    canvas.restore();

    // 给整体加极轻的从上到下的微弱淡色，以贴近截图下半部“几乎白但有点底色”的感觉
    final fade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFFFFAF8), Colors.white],
      stops: const [0.0, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = fade..blendMode = BlendMode.srcOver);
  }

  @override
  bool shouldRepaint(covariant _HeaderGlowPainter oldDelegate) => false;
}
