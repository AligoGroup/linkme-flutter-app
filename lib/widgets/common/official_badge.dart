import 'package:linkme_flutter/core/theme/linkme_material.dart';

class OfficialBadge extends StatelessWidget {
  final double size;
  const OfficialBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: size),
          const SizedBox(width: 2),
          const Text('官方', style: TextStyle(color: Colors.white, fontSize: 10, height: 1.1)),
        ],
      ),
    );
  }
}

