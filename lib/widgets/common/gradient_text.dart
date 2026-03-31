import 'package:linkme_flutter/core/theme/linkme_material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(this.text, {super.key, required this.style, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

