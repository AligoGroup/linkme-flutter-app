import 'package:linkme_flutter/core/theme/linkme_material.dart';

/// Draw an icon filled with a gradient via ShaderMask.
/// Keep this lightweight so it can be used inside IconButton.
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;

  const GradientIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) {
        return gradient.createShader(Rect.fromLTWH(0, 0, size, size));
      },
      child: SizedBox(
        width: size,
        height: size,
        // Icon color itself doesn't matter because ShaderMask applies srcIn
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}

/// Convenience IconButton that uses [GradientIcon].
class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;
  final VoidCallback? onPressed;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.gradient,
    this.size = 22,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: GradientIcon(icon: icon, size: size, gradient: gradient),
    );
  }
}
