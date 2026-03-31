import 'package:linkme_flutter/core/theme/linkme_material.dart';

/// A tiny helper widget to animate child with fade + slide-in.
/// - Starts after [delay]
/// - Slides from (offsetX, offsetY) to (0, 0) while fading 0->1
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final double offsetX;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay = Duration.zero,
    this.offsetY = 12,
    this.offsetX = 0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: widget.curve);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) {
        final t = _fade.value;
        final dx = (1 - t) * widget.offsetX;
        final dy = (1 - t) * widget.offsetY;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      child: widget.child,
    );
  }
}

