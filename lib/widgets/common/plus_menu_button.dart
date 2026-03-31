import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';

class PlusMenuItem {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const PlusMenuItem({required this.icon, required this.text, required this.onTap});
}

/// 自定义“加号”弹出菜单：
/// - 菜单显示在加号下方，距加号底部 3px；
/// - 菜单右侧与加号按钮右侧对齐；
/// - 背景透明灰色遮罩；
/// - 菜单白色背景，宽高由内容决定；
/// - 图标与文本在每一行居中显示；
/// - 弹出时加号图标高亮；
class PlusMenuButton extends StatefulWidget {
  final List<PlusMenuItem> items;
  final Color iconColor;
  final Color highlightColor;
  final double spacingToButton;
  const PlusMenuButton({
    super.key,
    required this.items,
    this.iconColor = AppColors.textSecondary,
    this.highlightColor = AppColors.primary,
    this.spacingToButton = 3,
  });

  @override
  State<PlusMenuButton> createState() => _PlusMenuButtonState();
}

class _PlusMenuButtonState extends State<PlusMenuButton> {
  final GlobalKey _btnKey = GlobalKey();
  OverlayEntry? _entry;
  bool _open = false;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _toggle() => _open ? _remove() : _show();

  void _remove() {
    _entry?.remove();
    _entry = null;
    if (_open && mounted) setState(() => _open = false);
  }

  void _show() {
    // 使用根 Overlay，避免处于 AppBar actions 等嵌套 Overlay 中导致弹层被后续部件覆盖或未显示。
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;
    final rb = _btnKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final offset = rb.localToGlobal(Offset.zero);
    final size = rb.size;
    final screen = MediaQuery.of(context).size;
    final double right = screen.width - (offset.dx + size.width);
    final double top = offset.dy + size.height + widget.spacingToButton;

    _entry = OverlayEntry(
      builder: (ctx) => _PlusMenuOverlay(
        anchorRight: right,
        top: top,
        items: widget.items,
        onDismiss: _remove,
      ),
    );

    overlay.insert(_entry!);
    if (mounted) setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final color = _open ? widget.highlightColor : widget.iconColor;
    return IconButton(
      key: _btnKey,
      icon: Icon(Icons.add, color: color),
      onPressed: _toggle,
    );
  }
}

class _PlusMenuOverlay extends StatefulWidget {
  final double anchorRight;
  final double top;
  final List<PlusMenuItem> items;
  final VoidCallback onDismiss;
  const _PlusMenuOverlay({required this.anchorRight, required this.top, required this.items, required this.onDismiss});

  @override
  State<_PlusMenuOverlay> createState() => _PlusMenuOverlayState();
}

class _PlusMenuOverlayState extends State<_PlusMenuOverlay> {
  final GlobalKey _menuKey = GlobalKey();
  Rect? _menuRect; // global rect of menu (for creating mask hole)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final r = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (r == null) return;
    final pos = r.localToGlobal(Offset.zero);
    setState(() {
      _menuRect = pos & r.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // 遮罩（带透明灰色，菜单区域挖洞，不遮住背后的内容，保证磨砂有效）
      Positioned.fill(
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: CustomPaint(
            painter: _DimWithHolePainter(_menuRect),
          ),
        ),
      ),
      // 菜单主体
      Positioned(
        right: widget.anchorRight,
        top: widget.top,
        child: ClipRRect(
          key: _menuKey,
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.white.withOpacity(0.92),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: widget.items.map((i) => _MenuItem(i, onTap: () { widget.onDismiss(); i.onTap(); })).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _DimWithHolePainter extends CustomPainter {
  final Rect? menuRect;
  const _DimWithHolePainter(this.menuRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.35);
    final bg = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (menuRect != null) {
      final hole = Path()..addRRect(RRect.fromRectAndRadius(menuRect!, const Radius.circular(10)));
      final finalPath = Path.combine(PathOperation.difference, bg, hole);
      canvas.drawPath(finalPath, paint);
    } else {
      canvas.drawPath(bg, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DimWithHolePainter oldDelegate) => oldDelegate.menuRect != menuRect;
}

class _MenuItem extends StatelessWidget {
  final PlusMenuItem item;
  final VoidCallback onTap;
  const _MenuItem(this.item, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(item.text, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
