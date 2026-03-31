import 'package:linkme_flutter/core/theme/linkme_material.dart';

/// Link Me loading animation: gray hand-written text with purple-pink sweep.
/// - Default shows "Link Me" in a script-like font, base gray.
/// - A left-to-right gradient sweep animates continuously while loading.
/// - If [compact] is true, shows "LM" for tight spaces (e.g., buttons/icons).
class LinkMeLoader extends StatefulWidget {
  final double fontSize; // Text size in logical pixels
  final bool compact; // Use "LM" instead of "Link Me"
  final Duration period; // Sweep loop duration
  final String? semanticsLabel;
  final String? fontFamily; // Optional custom font family if provided via assets

  const LinkMeLoader({
    super.key,
    this.fontSize = 20,
    this.compact = false,
    this.period = const Duration(milliseconds: 1200),
    this.semanticsLabel,
    this.fontFamily,
  });

  @override
  State<LinkMeLoader> createState() => _LinkMeLoaderState();
}

class _LinkMeLoaderState extends State<LinkMeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefer provided font family, otherwise try a nice built-in script font on iOS/macOS.
    final String? family = widget.fontFamily ?? 'Snell Roundhand';
    final baseStyle = TextStyle(
      fontFamily: family,
      // Fallbacks in case platform lacks the family
      fontFamilyFallback: const [
        'Bradley Hand',
        'Segoe Script',
        'Zapfino',
        'cursive',
      ],
      color: const Color(0xFFB0B0B0), // base gray
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.6,
      height: 1.0,
    );

    final String text = widget.compact ? 'LM' : 'Link Me';

    return Semantics(
      label: widget.semanticsLabel ?? 'Loading',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Base gray text
              Text(text, style: baseStyle),
              // Sweeping gradient mask
              ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (Rect r) {
                  const grad = LinearGradient(
                    colors: [Color(0xFFB388FF), Color(0xFFFF8BD4)],
                  );
                  final w = r.width;
                  // Sweep from left to right repeatedly
                  final t = _ctrl.value; // 0..1
                  final from = (t * 1.3 - 0.15).clamp(0.0, 1.0);
                  final to = (from + 0.45).clamp(0.0, 1.0);
                  return grad.createShader(
                    Rect.fromLTWH(w * from, 0, w * (to - from), r.height),
                  );
                },
                child: Text(text, style: baseStyle),
              ),
            ],
          );
        },
      ),
    );
  }
}

